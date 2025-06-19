#!/usr/bin/env zsh

# このスクリプトはNHKの放送局のアーカイブには使えません
echo 'NHK(JOAK/JOAB) is NOT supported.'

# URLを入力します
read "URL?URL?: "
DATE="$(echo ${=URL} | rev | awk '{print substr($0, 3, 12)}' | rev)"
DATE_S="$(echo ${=DATE} | awk '{print substr($0, 1, 8)}')"
TIME_S="$(echo ${=DATE} | awk '{print substr($0, 9, 4)}')"
STATION="$(echo ${=URL} | awk '{split($0, array, "/"); print array[6]}')"

# 出力されるファイル名を入力します
echo 'Output filename example: yymmdd_"Your-input-name".m4a'
read "FILE?File name? (extension is unnecessary): "

# 放送終了時間を入力します
read "TIME_E?End time? (Example: 1330(hhmm), Range: 0 ~ 2900): "
# 日付の判定をしています
if [[ ${=TIME_E} -ge 2400 ]]; then
    if [[ (${=TIME_S} -gt 1200) && (${=TIME_S} -lt 2400) ]]; then
	DATE_E=$(( ${=DATE_S} + 1))
    else
	DATE_E=${=DATE_S}
    fi
    TIME_E=$(echo $(( ${=TIME_E} - 2400 )) | awk '{printf "%04d", $0}')
else
    DATE_E=${=DATE_S}
    TIME_E=$(echo ${=TIME_E} | awk '{printf "%04d", $0}')    
fi

if [[ (${=TIME_S} -ge 0) && (${=TIME_S} -lt 500) ]]; then
    FILE="$(( $(echo ${=DATE_S} | awk '{print substr($0, 3)}') - 1 ))_${FILE}"
else
    FILE="$(echo ${=DATE_S} | awk '{print substr($0, 3)}')_${FILE}"
fi

# authtokenを入力します
read "TOKEN?Auth token?: "

# FFmpegによって出力します
ffmpeg -headers "x-radiko-authtoken:$TOKEN" -i "https://radiko.jp/v2/api/ts/playlist.m3u8?l=15&station_id=${=STATION:u}&ft=${=DATE_S}${=TIME_S}00&to=${=DATE_E}${=TIME_E}00" -vn -c:a copy ./$FILE.m4a
