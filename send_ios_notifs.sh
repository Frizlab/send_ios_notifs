#!/bin/bash

usage() {
	echo "$0 sandbox|prod file_with_tokens message_to_send"
}

# There may be a solution with xxd, but I didn't want to spend the
# time to understand it
echobyte() {
	if (( $1 >= 0 && $1 <= 255 )); then
		printf "\\x$(printf "%x" $1)"
	else
		printf "Invalid value\n" >&2
		return 1
	fi
}

dir_name="$(dirname "$0")"
echo $dir_name

if [ "$#" -ne 3 ]; then
	usage
	exit 42
fi

prod_or_sandbox="$1"
tokens="$2"
message="$3"

if [ "$prod_or_sandbox" != "prod" -a "$prod_or_sandbox" != "sandbox" ]; then
	usage
	exit 42
fi

payload='{"aps":{"alert":"'"$(printf "$(echo -n "$message" | sed -E -e 's/%/%%/g')" | sed -E -e 's/"/\\"/g')"'"}}'
payload_len=$(echo -n "$payload" | wc -c | tr -d ' '); # Here, printf instead of echo -n won't work if payload contains for instance a double-quote
if [ $payload_len -gt 255 ]; then
	echo "Payload is too long." >/dev/stderr
	exit 2
fi
echo "Payload: $payload (len = $payload_len)"

if [ ! -f "$tokens" ]; then
	echo "$0: $tokens: no such file" >/dev/stderr
	exit 21
fi

temp_input="$(mktemp input.XXXX)" || exit 2

endiantest=$(echo -n I | od -to2 | awk '{print substr($2,6,1); exit}')
# endiantest == 1 on little endian machines
if [ $endiantest -eq 1 ]; then first_mask=$((0xFF00)); second_mask=$((0x00FF)); first_shift=1; second_shift=0;
else                           first_mask=$((0x00FF)); second_mask=$((0xFF00)); first_shift=0; second_shift=1;
fi

i=0
cat "$tokens" | sort | uniq | while read t; do
	# Compute len of the binary token from the base64 encoded value (t)
	pos=$(echo "$t" | sed -E 's/=.*$//' | wc -c)
	pos=$((pos-1)); # There's an additional new line added by sed
	pos_on_four=$((pos/4))
	token_len=$((pos_on_four * 3))
	check=$((pos - (pos_on_four*4)))
	case $check in
		2) token_len=$((token_len+1));;
		3) token_len=$((token_len+2));;
	esac
	echo "Got token \"$t\"; len = $token_len (#$i)"

	# Message for simple format is: |COMMAND|TOKENLEN|TOKEN|PAYLOADLEN|PAYLOAD|, with COMMAND=0
	echobyte 0 >>"$temp_input"
#	echobyte 1 >>"$temp_input"
#	echobyte $(((i & 0xFF000000) >> 3)) >>"$temp_input"
#	echobyte $(((i & 0x00FF0000) >> 2)) >>"$temp_input"
#	echobyte $(((i & 0x0000FF00) >> 1)) >>"$temp_input"
#	echobyte $(((i & 0x000000FF) >> 0)) >>"$temp_input"
#	echobyte 0 >>"$temp_input"
#	echobyte 0 >>"$temp_input"
#	echobyte 0 >>"$temp_input"
#	echobyte 0 >>"$temp_input"
	echobyte $(((token_len & first_mask)  >> first_shift))  >>"$temp_input"
	echobyte $(((token_len & second_mask) >> second_shift)) >>"$temp_input"

	echo $t | base64 -D >>"$temp_input"
	echobyte $(((payload_len & first_mask)  >> first_shift))  >>"$temp_input"
	echobyte $(((payload_len & second_mask) >> second_shift)) >>"$temp_input"
	echo -n "$payload" >>"$temp_input"

	i=$((i+1))
done

# Now i == 0, because all the increments are done in the while, which is in a subshell.
# We cannot print the count of tokens! :(

if [ "$prod_or_sandbox" = "prod" ]; then
	openssl s_client -connect gateway.push.apple.com:2195         -cert "$dir_name/certificates/apple_push_certificate.pem"         -pass "pass:$(cat "$dir_name/certificates/apple_push_certificate.pass" 2>/dev/null)" <"$temp_input" >/dev/null
else
	openssl s_client -connect gateway.sandbox.push.apple.com:2195 -cert "$dir_name/certificates/apple_push_certificate_sandbox.pem" -pass "pass:$(cat "$dir_name/certificates/apple_push_certificate_sandbox.pass" 2>/dev/null)" <"$temp_input" >/dev/null
fi

rm -f "$temp_input"
