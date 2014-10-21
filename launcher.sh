##################
# Part of amp.pl #
##################

#!/bin/bash
source /root/.bash_profile

case "$1" in
        "parse")
                perl /root/bin/gsp/gsp.pl parse
                ;;
        "send")
                perl /root/bin/gsp/gsp.pl send
                ;;
        *)
                echo "Usage: $0 [parse|send]"
                ;;
esac