# both $1 and $2 are absolute paths beginning with /
# returns relative path to $2/$target from $1/$source
rel_path()
{
    local insource=$1
    local intarget=$2

    # Ensure both source and target end with /
    # This simplifies the inner loop.
    #echo "insource : \"$insource\""
    #echo "intarget : \"$intarget\""
    case "$insource" in
        */) ;;
        *) source="$insource"/ ;;
    esac

    case "$intarget" in
        */) ;;
        *) target="$intarget"/ ;;
    esac

    #echo "source : \"$source\""
    #echo "target : \"$target\""

    local common_part=$source # for now

    local result=""

    #echo "common_part is now : \"$common_part\""
    #echo "result is now      : \"$result\""
    #echo "target#common_part : \"${target#$common_part}\""
    while [ "${target#$common_part}" = "${target}" -a "${common_part}" != "//" ]; do
        # no match, means that candidate common part is not correct
        # go up one level (reduce common part)
        common_part=$(dirname "$common_part")/
        # and record that we went back
        if [ -z "${result}" ]; then
            result="../"
        else
            result="../$result"
        fi
        #echo "(w) common_part is now : \"$common_part\""
        #echo "(w) result is now      : \"$result\""
        #echo "(w) target#common_part : \"${target#$common_part}\""
    done

    #echo "(f) common_part is     : \"$common_part\""

    if [ "${common_part}" = "//" ]; then
        # special case for root (no common path)
        common_part="/"
    fi

    # since we now have identified the common part,
    # compute the non-common part
    forward_part="${target#$common_part}"
    #echo "forward_part = \"$forward_part\""

    if [ -n "${result}" -a -n "${forward_part}" ]; then
        #echo "(simple concat)"
        result="$result$forward_part"
    elif [ -n "${forward_part}" ]; then
        result="$forward_part"
    fi
    #echo "result = \"$result\""

    # if a / was added to target and result ends in / then remove it now.
    if [ "$intarget" != "$target" ]; then
        case "$result" in
            */) result=$(echo "$result" | awk '{ string=substr($0, 1, length($0)-1); print string; }' ) ;;
        esac
    fi

    echo $result

    return 0
}

