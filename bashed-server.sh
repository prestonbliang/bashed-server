#!/bin/bash
#my bashed web server!!!
#ok so basically, bash cant listten on a port itself, so the script is gna use socat
#socat makes new copy of his script for each connection
#how to use my script
# ./bashed-server.sh [-p port] [-d folder] [-b address] [-n]
# -p = port to listen, default 8080
# -d = folder to serve 
# -b = address to listen on
# -n turn off folder listings
# -h help

# help funcitons to show when they use -h
show_help() {
    echo "usage: $0 [-p port] [-d folder] [-b address] [-n]"
    echo "  -p port: port to listen on (default: 8080)"
    echo "  -d folder: folder to serve (default: .)"
    echo "  -b address: address to listen on (default: 127.0.0.1)"
    echo "  -n: turn off folder listings"
    echo "  -h: show this help message"
}

#ok now we are going to print one line in terminal for each request
log() {
    clean_path=$(printf '%s' "$path" | tr -cd '[:print:]')
    echo "$(date +%T) ${SOCAT_PEERADDR:-?} $method $clean_path - $1" >&2
}

#for this one #1 is goin to be status, $2 is the content type, $3 is length, and $4 is extra header
send_headers() {
    printf 'HTTP/1.1 %s\r\n' "$1"
    printf 'Content-Type: %s\r\n' "$2"
    printf 'Content-Length: %s\r\n' "$3"
    if [ -n "$4" ]; then
        printf '%s\r\n' "$4"
        fi
        printf '\r\n'
}

#for send text, same thing except $3is body
send_text() {
    send_headers "$1" "$2" "${#3}" "$4"
    printf '%s' "$3"
    log "$1"
}

send_error() {
    send_text "$1" "text/plain" "$1"
}

#guess content type from filename
get_type() {
    case "$1" in
        *.html|*.htm) echo "text/html; charset=utf-8" ;;
        *.css)        echo "text/css" ;;
        *.js)         echo "text/javascript" ;;
        *.json)       echo "application/json" ;;
        *.txt|*.md)   echo "text/plain; charset=utf-8" ;;
        *.png)        echo "image/png" ;;
        *.jpg|*.jpeg) echo "image/jpeg" ;;
        *.gif)        echo "image/gif" ;;
        *.svg)        echo "image/svg+xml" ;;
        *.ico)        echo "image/x-icon" ;;
        *.pdf)        echo "application/pdf" ;;
        *)            echo "application/octet-stream" ;;
    esac
}

#ok now make text safe to put in html
escape_html() {
    printf '%s\n' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

#page to list everything in folder
send_listing() {
    dir="$1"
    title=$(escape_html "Index of $2")

    html="<html><head><title>$title</title></head><body>"
    html="$html<h1>$title</h1><ul>"

    #link to parent folder, except in top fodder
    if [ "$2" != "/" ]; then
        html="$html<li><a href=\"../\">../</a></li>"
    fi

    for item in "$dir"*; do
        if [ ! -e "$item" ]; then
            continue
        fi
        name=$(basename "$item")
        if [ -d "$item" ]; then
            name="$name/"
        fi
        label=$(escape_html "$name")
        link=$(escape_html "${name// /%20}")
        html="$html<li><a href=\"$link\">$label</a></li>"
    done
    html="$html</ul></body></html>"
    send_text "200 OK" "text/html; charset=utf-8" "$html"
}


#handle a request!!!! main function to do

handle_request() {
    #im gonna use plain bytes so that ${var} gives the right thingy
    export LC_ALL=C

    read -r -t 10 method path version || return

    #let me think
    #ttt
    #ttt
    #Ttt3
    #ok i got it
    while read -r -t 10 line; do
        line=${line%%$'\r'}
        if [ -z "$line" ]; then
            break
        fi
    done
    if [ "$method" != "GET" ]; then
        send_error "405 Method Not Allowed" "text/plain" "405 Method Not Allowed" "Allow: GET"
        return
    fi

    case "$path" in
        /*) ;;
        *) send_error "400 Bad Request bomboclat" "text/plain" "400 Bad Request"; return ;;
    esac


#cut off query string and fragment
    path=${path%%\?*}

    #decode url encoding
    path=${path//\\/\\\\}
    path=$(printf '%b' "${path//%/\\x}")

    #no ".." plus hidden files like .git or .env
    case "$path" in
        *..*|*/.*) send_error "403 Forbidden bomboclat" "text/plain" "403 Forbidden"; return ;;
    esac

    file="$FOLDER$path"
    #a folder : go to slash version then look for index.html or index.htm
    if [ -d "$file" ]; then
        if [ "${path: -1}" != "/" ]; then
            send_text "301 Moved Permanently" "text/plain" "Moved" "Location: ${path// /%20}/"
            return
        fi
        if [ -f "$file/index.html" ]; then
            file="$file/index.html"
        elif [ "$LISTING" = "yes" ]; then
            send_listing "$file" "$path"
            return
        else
            send_error "403 Forbidden bomboclat" "text/plain" "403 Forbidden"
            return
        fi
    fi

    if [ ! -f "$file" ]; then
        send_error "404 Not Found bomboclat" "text/plain" "404 Not Found"
        return
    fi

    if [ ! -r "$file" ]; then
        send_error "403 Forbidden bomboclat" "text/plain" "403 Forbidden"
        return
    fi

    size=$(wc -c <"$file")
    type=$(get_type "$file")
    send_headers "200 OK bomboclat" "$type" "$size"
    cat "$file"
    log "200 OK"
}
#ok this part done, let me push to repo after checking mistypes

#now its time to start the server

if [ "$1" = "--handle" ]; then
    handle_request
    exit 0
fi

PORT=8080
FOLDER="."
ADDRESS="127.0.0.1"
LISTING="yes"

while getopts "p:d:b:nh" opt; do
    case "$opt" in
        p) PORT="$OPTARG" ;;
        d) FOLDER="$OPTARG" ;;
        b) ADDRESS="$OPTARG" ;;
        n) LISTING="no" ;;
        h) show_help; exit 0 ;;
        *) show_help; exit 1 ;;
    esac
done

case "$PORT" in
    ''|*[!0-9]*) echo "error: invalid port number"; exit 1 ;;
esac

if [ ! -d "$FOLDER" ]; then
    echo "error: folder does not exisst: $FOLDER"
    exit 1
fi

#use full path for folder
FOLDER=$(cd "$FOLDER" && pwd)
if [ "$FOLDER" = "/" ]; then
    echo "error: please dont serve entire filesystem idiot"
    exit 1
fi

if ! command -v socat > /dev/null; then
    echo "error: socat is needed, bomboclat use sudo apt install socat"
    exit 1
fi

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
export FOLDER LISTING
echo "bashed web server listening on $ADDRESS:$PORT, serving $FOLDER"
socat "TCP-LISTEN:$PORT,bind=$ADDRESS,reuseaddr,fork" "SYSTEM:bash $SELF --handle"
