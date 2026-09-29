#!/usr/bin/python3
# Google's device authorization flow (urn:ietf:params:oauth:grant-type:device_code) only
# accepts an allowlisted subset of scopes - it rejects the Google Tasks scope outright
# ("Invalid device flow scope"), confirmed by live testing, not just documentation. Since
# this widget needs both Calendar and Tasks scopes under one login, it uses the loopback
# redirect flow instead (the one Google recommends generally for desktop apps), which has
# no such scope restriction: https://developers.google.com/identity/protocols/oauth2/native-app
#
# This script binds http://127.0.0.1:<port>, THEN opens the browser to Google's consent URL
# itself (rather than QML opening the browser separately and hoping this script wins the
# race to bind the port first - confirmed by testing that Google can redirect back fast
# enough, eg. if already logged in, to beat a separately-launched Python process starting up),
# and waits for exactly one incoming request (Google's redirect after the user approves/
# denies access).
#
# The result is written to --result-file as one line, not just printed to stdout: Plasma's
# "executable" DataSource engine only reports a command's output once the process exits, and
# in testing it never reliably delivered that for this specifically long-running/blocking
# script (every other command in this app is near-instant) - QML instead launches this
# backgrounded and polls the result file with quick, separate commands.
#   CODE:<authorization code>
#   ERROR:access_denied|port_in_use|timeout|<whatever Google's ?error= param said>
import sys
import argparse
import http.server
import urllib.parse
import webbrowser

SUCCESS_HTML = b"""<!DOCTYPE html><html><head><meta charset="utf-8"><title>Event Calendar</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:15%">
<h2>Login successful</h2><p>You can close this tab and return to the widget.</p>
</body></html>"""

ERROR_HTML = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>Event Calendar</title></head>
<body style="font-family:sans-serif;text-align:center;margin-top:15%">
<h2>Login failed</h2><p>{}</p><p>You can close this tab and return to the widget.</p>
</body></html>"""


class RedirectHandler(http.server.BaseHTTPRequestHandler):
	def do_GET(self):
		query = urllib.parse.urlparse(self.path).query
		params = urllib.parse.parse_qs(query)
		self.send_response(200)
		self.send_header('Content-Type', 'text/html; charset=utf-8')
		self.end_headers()
		if 'code' in params:
			self.server.oauth_code = params['code'][0]
			self.wfile.write(SUCCESS_HTML)
		else:
			error = params.get('error', ['unknown_error'])[0]
			self.server.oauth_error = error
			self.wfile.write(ERROR_HTML.format(error).encode('utf-8'))

	def log_message(self, format, *args):
		pass # Don't spam stderr; ExecUtil only cares about our final stdout line.


def main():
	parser = argparse.ArgumentParser(description='One-shot local HTTP listener for Google OAuth loopback redirects.')
	parser.add_argument('--port', type=int, required=True)
	parser.add_argument('--auth-url', required=True, help="Opened in the browser only after the port is bound, so Google can never redirect back before we're listening.")
	parser.add_argument('--result-file', required=True)
	parser.add_argument('--timeout', type=int, default=180)
	args = parser.parse_args()

	def write_result(line):
		with open(args.result_file, 'w') as f:
			f.write(line + '\n')
		print(line)

	try:
		server = http.server.HTTPServer(('127.0.0.1', args.port), RedirectHandler)
	except OSError:
		write_result('ERROR:port_in_use')
		return

	server.oauth_code = None
	server.oauth_error = None
	server.timeout = args.timeout
	webbrowser.open(args.auth_url)
	server.handle_request() # Blocks for exactly one request, or until timeout.
	server.server_close()

	if server.oauth_code:
		write_result('CODE:' + server.oauth_code)
	elif server.oauth_error:
		write_result('ERROR:' + server.oauth_error)
	else:
		write_result('ERROR:timeout')


if __name__ == '__main__':
	main()
