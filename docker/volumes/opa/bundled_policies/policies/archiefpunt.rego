package archiefpunt.authz

#docker-compose exec opa /opa eval -i /policies/input.json -d /policies/archiefpunt.rego -d /policies/data.json 'data.archiefpunt.authz.allow'
#docker-compose exec opa /opa build --bundle --output /bundled_policies/archiefpunt.tar.gz /policies

import future.keywords.in

import data.acl
import data.readonlytabellen
import data.roles

default allow = false

runtime = opa.runtime()

allow {
	input.method in ["GET", "OPTIONS"]
	token.valid
	acl[token.user]

	token.role[_] in roles
}

allow {
	input.method in ["POST", "PUT"]
	token.valid
	acl[token.user]

	token.role[_] = "full"
}

allow {
	input.method == "DELETE"
	token.valid
	acl[token.user]

	token.role[_] = "full"
	#    not input.path in readonlytabellen
}

allow {
	input.method in ["POST", "PUT", "DELETE"]
	token.valid
	acl[token.user]

	token.role[_] == "full-min"
	not input.path in readonlytabellen
}

token := {"valid": valid, "user": payload.user, "role": payload.role} {
	[valid, _, payload] := io.jwt.decode_verify(input.token, {"secret": runtime.env.SECRET})
}
