#!/bin/env zsh
# 変数宣言(適宜変更してください)
TEMP_A1='./auth1'
TEMP_A2='./auth2'
TEMP_DOM='./dom'
DOWNDIR='./'
URL=()
NOW_TIME="$(date '+%-H%M')"
NOW_DOW="$(date '+%w')"
if (( ${NOW_TIME} >= 0 && ${NOW_TIME} < 500 )); then
    OLDEST="$(date '+%Y/%-m/%-d (%a) %k:%M' -d '8 days ago 5:00')"
    OLDEST_NUM="$(date '+%Y%m%d%H%M' -d '8 days ago 5:00')"
    OLDEST_DOW="$(date '+%w' -d '8 days ago 5:00')"
else
    OLDEST="$(date '+%Y/%-m/%-d (%a) %k:%M' -d 'week ago 5:00')"
    OLDEST_NUM="$(date '+%Y%m%d%H%M' -d 'week ago 5:00')"
    OLDEST_DOW="$(date '+%w' -d 'week ago 5:00')"
fi
BROWSER='chromium'

# 依存コマンドの確認
CHK_DEPEND() {
    case "$(which curl)" in
	'curl not found')
	    echo 'cURLがないか、PATHにありません。終了します。'
	    exit
	    ;;
    esac
    case "$(which ffmpeg)" in
	'ffmpeg not found')
	    echo 'FFmpegがないか、PATHにありません。終了します。'
	    exit
	    ;;
    esac
    case "$(which ${BROWSER})" in
	"${BROWSER} not found")
	    echo 'Chromiumがないか、PATHにありません。終了します。'
	    echo 'なおChromium系の他のブラウザでも代用できます。'
	    echo 'このとき、19行目のBROWSERの値を変更してください。'
	    exit
	    ;;
    esac    
}

# auth1を獲得
GET_AUTH1() {
    curl -s -H 'x-radiko-app: pc_html5' -H 'x-radiko-app-version: 0.0.1' -H 'x-radiko-device: pc' -H 'x-radiko-user: dummy_user' -i -L 'https://radiko.jp/v2/api/auth1' | tr -d '\r' > "${TEMP_A1}"
    a1_authtoken="$(cat "${TEMP_A1}" | grep -i 'authtoken' | awk '{print $2}')"
    a1_keylength="$(cat "${TEMP_A1}" | grep -i 'keylength' | awk '{print $2}')"
    a1_keyoffset=$(("$(cat "${TEMP_A1}" | grep -i 'keyoffset' | awk '{print $2}')+1"))
    rm "${TEMP_A1}"
}

# auth2を獲得
GET_AUTH2() {
    a1_authkey='bcd151073c03b352e1ef2fd66c32209da9ca0afa'
    a1_partialkey="$(echo ${a1_authkey} | awk -v offset=${a1_keyoffset} -v len=${a1_keylength} '{printf substr($0, offset, len)}' | base64 | tr -d '\n')"
    curl -s -H "x-radiko-authtoken: ${a1_authtoken}" -H "x-radiko-partialKey: ${a1_partialkey}" -H "x-radiko-device: pc" -H 'x-radiko-user: dummy_user' -i -L 'https://radiko.jp/v2/api/auth2' | tr -d '\r' > "${TEMP_A2}"
    
    a2_status="$(cat "${TEMP_A2}" | awk 'NR==1 {print $2}')"
    case ${a2_status} in
	200)
	    a2_area="$(cat "${TEMP_A2}" | awk -F'[, ]' 'NR==14 {print $2}')"
	    ;;
	*)
	    OUT=1
	    ;;
    esac
    rm "${TEMP_A2}"
}

# 手動でURLを入力
INPUT_URL() {
    URL_EMPTY=0
    echo '保存したい番組のタイムシフトURLを入力してください。(例: https://radiko.jp/#!/ts/LFR/20260101000000)'
    echo '追加するものがない場合はそのままEnterを押してください。'
    read 'URL_IN?'
    if [[ -z "$(echo ${URL_IN} | grep -e 'radiko.jp/#!/ts')" ]]; then
	URL_EMPTY=1
	if (( ${#URL[@]} == 0 )); then
	    echo '保存する番組が1つもありません。終了します。'
	    exit
	fi
    else
	if [[ ${URL_IN:0:4} == 'http' ]]; then
	    URL+=("https://radiko.jp/#!/ts/$(echo ${URL_IN} | cut -d '/' -f 6-)")
	elif [[ ${URL_IN:0:6} == 'radiko' ]]; then
	    URL+=("https://radiko.jp/#!/ts/$(echo ${URL_IN} | cut -d '/' -f 4-)")
	else
	    echo 'URLの形式が正しくないかもしれませんが続行します。\n'
	fi
    fi

    while (( ${URL_EMPTY} != 1 )); do
	echo '\nさらに保存したい番組のタイムシフトURLを入力してください。(例: https://radiko.jp/#!/ts/LFR/20260101000000)'
	echo '追加するものがない場合はそのままEnterを押してください。'
	read 'URL_IN?'
	if [[ -z "$(echo ${URL_IN} | grep -e 'radiko.jp/#!/ts')" ]]; then
	    URL_EMPTY=1
	else
	    if [[ ${URL_IN:0:4} == 'http' ]]; then
		URL+=("https://radiko.jp/#!/ts/$(echo ${URL_IN} | cut -d '/' -f 6-)")
	    elif [[ ${URL_IN:0:6} == 'radiko' ]]; then
		URL+=("https://radiko.jp/#!/ts/$(echo ${URL_IN} | cut -d '/' -f 4-)")
	    else
		echo 'URLの形式が正しくないかもしれませんが続行します。\n'
	    fi
	fi
    done
}

# 手動で認証トークンを入力
INPUT_AUTHTOKEN() {
    if [[ -n ${authtoken} ]]; then
	case ${#authtoken} in
	    22)
		a1_authtoken=${authtoken}
		;;
	    *)
		if [[ ${authtoken} == 'x-radiko-authtoken' ]]; then
		    read 'authtoken? <- 進まない場合はEnterを押してください。'
		    authtoken="$(echo ${authtoken} | tr -d '\ \t\r\n')"
		    a1_authtoken=${authtoken}
		elif [[ -n "$(echo ${authtoken} | grep -i 'x-radiko-authtoken')" ]]; then
		    authtoken="$(echo ${authtoken} | tr -d '\ \t\r\n' | awk '{printf substr($0, length($0)-21)}')"
		    a1_authtoken=${authtoken}
		else
		    echo '認証トークンの形式が誤っています。終了します。'
		    exit
		fi
		;;
	esac
    else
	if [[ -n ${OUT} ]]; then
	    echo '認証トークンがないため保存できません。終了します。'
	    exit
	fi
    fi   
}

# 番組の情報を入手します
GET_INFO() {
    for i in {1..${#URL[@]}}; do
    ${BROWSER} --headless --disable-gpu --dump-dom ${URL[${i}]} > "${TEMP_DOM}"
    TITLE+=("$(echo $(cat "${TEMP_DOM}" | grep -e 'og:title' | awk -F '|' '{print $2}'))")
    DATETIME+=("$(echo $(cat "${TEMP_DOM}" | grep -e 'share-url' | awk -F '"' '{print $6}' | awk -F '=' '{print substr($4, 1, 12)}'))")
    TIME+=("$(echo ${DATETIME[${i}]:8:4})")
    if (( ${TIME[${i}]} < 500 )); then
	DATE+=("$(date '+%y%m%d' -d "${DATETIME[${i}]:0:8} yesterday")")
    else
	DATE+=("$(date '+%y%m%d' -d "${DATETIME[${i}]:0:8}")")
    fi
    LINK+=("$(cat ${TEMP_DOM} | grep -e 'share-url' | awk -F '"' '{print $6}')")
    rm ${TEMP_DOM}
    done
}

# URLの中から必要なものを抜き出す
FILE_CHOOSER() {
    if (( ${#URL[@]} != 1 )); then
	for i in {1..${#URL[@]}}; do
	    echo "${i}. ${DATE[${i}]}_${TITLE[${i}]}"
	done
	echo '保存する番組の番号を入力してください。'
	echo '(例: 1 3 4 6)'
	echo 'すべてダウンロードする場合はEnterを押してください。'
	read 'ORDER?'
	if [[ -z ${ORDER} ]]; then
	    for i in {1..${#URL[@]}}; do
		ORDER_ARRAY+=(${i})
	    done
	else
	    ORDER_C="$(echo ${ORDER} | tr ' ' '\n' | sort -u)"
	    ORDER_R="$(echo ${ORDER_C} | tr -d '\n')"
	    ORDER_NUM="$(echo ${ORDER_C} | wc -l)"
	    for i in {1..${ORDER_NUM}}; do
		ORDER_ARRAY+=("$(echo ${ORDER_R:$((${i}-1)):1})")
	    done
	fi
    else
	ORDER_ARRAY+=(1)    
    fi
}

CHK_DEPEND
GET_AUTH1
GET_AUTH2

echo 'NHK(JOAK/JOAB)はサポートされていません。'
if [[ -n "${a2_area}" ]]; then
    echo "${a2_area}内の放送局の番組がアカウント不要で保存できます。"
    echo "${a2_area}外の放送局の番組を保存をしたい場合は別途認証トークンをご用意ください。"
else
    echo 'あなたが現在日本国内にいないか、ネットワークに問題があります。'
    echo 'ダウンロードする際に認証トークンを入力する必要があります。'
fi

echo "${OLDEST} 〜 $(date '+%Y/%-m/%-d (%a) %k:%M')の範囲で終了した番組が保存できます。\n放送中の番組もダウンロードできますが、放送に追いついてしまうと遅くなります。\n"
INPUT_URL

if (( ${a2_status} == 200 )); then
    echo "\n${a2_area}外の放送を保存するには認証トークンを入力してください。(例: x-radiko-authtoken: 0000000000000000000000)"
    echo "${a2_area}内の放送を保存する場合はそのままEnterを押してください。"
    read 'authtoken?'
    INPUT_AUTHTOKEN
else
    echo '認証トークンを入力してください。(例: x-radiko-authtoken: 0000000000000000000000)'
    read 'authtoken?'
    INPUT_AUTHTOKEN
fi

echo '保存する番組の情報を集めています。\n何もせずお待ち下さい。。。\n'
GET_INFO
FILE_CHOOSER

for i in ${ORDER_ARRAY[@]}; do
    echo "${i}. ${DATE[$i]}_${TITLE[$i]}"
done

read -k 'OK?この内容で保存しますか?: [Y/n]'
case ${OK} in
    [Nn])
	echo ''
	read -q 'OK?本当に何も保存せず終了しますか?: [y/N]'
	case ${OK} in
	    [Yy])
		echo '終了します。'
		exit
		;;
	esac
	:
	;;
    *)
	:
	;;
esac
	
for i in ${ORDER_ARRAY[@]}; do
    ffmpeg -headers "x-radiko-authtoken: ${a1_authtoken}" -i "${LINK[${i}]}" -vn -c:a copy "${DOWNDIR}/${DATE[${i}]}_${TITLE[${i}]}.m4a"
done   

case "$(which aacgain)" in
    'aacgain not found')
	:
	;;
    *)
	aacgain -e -c -t -p -s i ${DOWNDIR}/*.m4a
	;;
esac
