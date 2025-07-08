import http.server
import http.client
import socketserver
import json
import sys
import os
import ssl

#KUBERNETES_HOST = "kubernetes.default.svc.cluster.local"
KUBERNETES_HOST = os.getenv('KUBERNETES_ENDPOINT')
EXTERNAL_DOMAIN = os.getenv('DOMAIN')

TOKEN_FILENAME = "/var/run/secrets/kubernetes.io/serviceaccount/token"

PORT = 8000

class IRSAHandler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        return 'application/json'


def load_service_token():
    token_string = ""
    with open(TOKEN_FILENAME,"r") as f:
        token_string = f.read()
    return token_string

def write_files(openid_data,jwks_data):
    os.makedirs('.well-known', exist_ok=True)
    os.makedirs('openid/v1', exist_ok=True)

    with open(".well-known/openid-configuration", "w") as f:
        f.write(openid_data)
    with open("openid/v1/jwks", "w") as f:
        f.write(jwks_data)


def get_openid_content():

    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    service_token = load_service_token()
    conn = http.client.HTTPSConnection(KUBERNETES_HOST, context=context)

    conn.request("GET", "/.well-known/openid-configuration", headers={
        "Host": KUBERNETES_HOST,
        "Authorization": "Bearer "+ service_token.strip('\n')
        })
    response = conn.getresponse()
    if response.status != 200 :
        print("Got error following http status code while fetching well known endpoint :")
        sys.exit(1)
    else:
        openid_json = json.loads(response.read())
        #openid_json["issuer"] = "https://kubernetes.default.svc.cluster.local"
        openid_json["issuer"] = "https://" + EXTERNAL_DOMAIN
        openid_json["jwks_uri"] = "https://" + EXTERNAL_DOMAIN + "/openid/v1/jwks"
        openid_data = json.dumps(openid_json)

    conn.request("GET", "/openid/v1/jwks", headers={
        "Host": KUBERNETES_HOST,
        "Authorization": "Bearer "+  service_token.strip('\n')
        })
    response = conn.getresponse()
    if response.status != 200 :
        print("Got error following http status code while fetching jwks uri :"+ str(response.status))
        sys.exit(1)
    else:
        jwks_data = str(response.read(),'utf-8')

    conn.close()
    write_files(openid_data,jwks_data)
    return

def main():
    with socketserver.TCPServer(("", PORT), IRSAHandler) as httpd:
        print("serving at port", PORT)
        get_openid_content()

        httpd.serve_forever()

if __name__ == "__main__":
    main()