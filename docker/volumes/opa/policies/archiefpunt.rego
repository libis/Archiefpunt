package archiefpunt.authz
#docker-compose exec opa /opa eval -i /policies/input.json -d /policies/archiefpunt.rego 'data.policy.allow'
#docker-compose exec opa /opa build --bundle --output /bundled_policies/archiefpunt.tar.gz ./policies

import future.keywords.in

import data.acl
import data.roles

default allow=false

allow = true {
    input.method == "GET"
    token.valid
    acl[token.user]

    token.role[_] in roles
}

allow = true {
    input.method == "POST"
    token.valid
    acl[token.user]

    token.role[_] = "FULL"
}

allow = true {
    input.method == "PUT"
    token.valid
    acl[token.user]

    token.role[_] = "FULL"
}

allow = true {
    input.method == "DELETE"
    token.valid
    acl[token.user]

    token.role[_] = "FULL"
}

token := {"valid": valid, "user": payload.user, "role": payload.role } {
	[valid, _, payload] := io.jwt.decode_verify(input.token, {"secret": "c4198bb7a64f835ed8c589e42dc44d14"})
}

#acl := {
#  "antenna": ["full"],
#  "kadoc": ["read-only"]
#}

#roles := ["read-only", "full"]
