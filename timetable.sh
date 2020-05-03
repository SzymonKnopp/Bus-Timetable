#!/bin/bash
# Author           : Szymon Knopp, 175550 ( s175550@student.pg.edu.pl )
# Created On       : 10.04.20r.
# Last Modified By : Szymon Knopp, 175550 ( s175550@student.pg.edu.pl )
# Last Modified On : 03.05.20r.
# Version          : 1.2
#
# Description      : Script downloads data about buses in Tczew
# Opis               based on the data given by user
#                    (time, amount, day of a week, link to a webpage containing timetable).
#                    For more details, refer to manual page.
#
# Licensed under GPL (see /usr/share/common-licenses/GPL

#DEFAULT VALUES
DAY=1
TIME=$(date +"%H:%M")
AMOUNT=5

VERSION="1.2"

FAVORITES=favorites # path to a file containing saved data
echo "">>favorites

#PROCESS OPTIONS
ZENITY=1
while getopts hvf:d:t:c: OPT; do
    ZENITY=0
    case $OPT in
        h) man ./timetableMan
           exit ;;

        v) echo "Wersja: $VERSION"
           exit ;;

        f) #favorite timetable
            LINK=$(grep "$OPTARG" $FAVORITES | cut -d '#' -f 2)
            if [ -z "$LINK" ]; then
                echo "Taki rozkład jazdy nie istnieje w ulubionych"
                exit
            fi
        ;;

        d) DAY="$OPTARG";;

        t) TIME="$OPTARG";;

        c) AMOUNT="$OPTARG";;
    esac
done

if [ $ZENITY -eq 0 -a -z "$LINK" ]; then
    echo "Opcja '-f' jest obowiązkowa"
    exit
fi

ESCAPE=0
until [ $ESCAPE -eq 1 ]; do
    FAV_LIST=$(cat favorites | cut -d "#" -f 1)

    if [ $ZENITY -eq 1 ]; then
        FUNCTION=$(zenity --entry \
            --title "Rozkład jazdy" \
            --text "Co chcesz zrobić?\n\n1. Znajdź autobusy\n2. Dodaj rozkład jazdy\n3. Usuń rozkład jazdy\n4. Zakończ działanie" \
            --width 200 \
            2>/dev/null) # redirecting stderr to null to remove warning from terminal
    else
        ESCAPE=1
        FUNCTION=1
    fi

    case "$FUNCTION" in
        4) #EXIT
            ESCAPE=1 ;;

        2) #ADD TIMETABLE
            FORM=$(zenity --forms \
                --title "Rozkład jazdy" \
                --text "Wprowadź dane do\nzapisania w ulubionych" \
                --separator "#" \
                --add-entry "Nazwa:" \
                --add-entry "Link:" \
                2>/dev/null)
            NAME=$(echo $FORM | cut -d '#' -f 1 | sed 's/ /-/g')
            LINK=$(echo $FORM | cut -d '#' -f 2)
            echo "$NAME#$LINK">>$FAVORITES
            zenity --info \
                --title "Rozkład jazdy" \
                --text "Pomyślnie dodano do ulubionych" \
                --width 300 \
                2>/dev/null
        ;;

        3) #REMOVE TIMETABLE
            PICKED=$(zenity --list \
                --title "Rozkład jazdy" \
                --text "Wybierz rozkład do usunięcia" \
                --column="Nazwa" $FAV_LIST \
                2>/dev/null)
            sed -i /$PICKED/d $FAVORITES
            zenity --info \
                --title "Rozkład jazdy" \
                --text "Pomyślnie usunięto z ulubionych" \
                --width 300 \
                2>/dev/null
        ;;


        1) #GET BUSES
            if [ $ZENITY -eq 1 ]; then
                zenity --question \
                    --title "Rozkład jazdy" \
                    --text "Czy chcesz wybrać rozkład z ulubionych?" \
                    --width 200 \
                    2>/dev/null

                if [ $? -eq 1 ]; then
                    #MANUAL INPUT
                    LINK=$(zenity --entry \
                        --title  "Rozkład jazdy" \
                        --text "Wprowadź link, pod którym znajduje się żądany rozkład jazdy." \
                        2>/dev/null)
                else
                    #FROM FAVORITES
                    PICKED=$(zenity --list \
                        --title "Rozkład jazdy" \
                        --text "Wybierz rozkład jazdy" \
                        --column="Nazwa" $FAV_LIST \
                        2>/dev/null)
                    LINK=$(grep "$PICKED" $FAVORITES | cut -d '#' -f 2)
                fi

                #GET ADDITIONAL DATA
                FORM=$(zenity --forms \
                    --title="Rozkład jazdy" \
                    --text="Wprowadź pozostałe dane" \
                    --separator="#"  \
                    --add-entry="Dzień (1 - Dni powszednie, 2 - Soboty, 3 - Niedziele i święta):" \
                    --add-entry="Godzina (format - HH:MM):" \
                    --add-entry="Liczba autobusów" \
                    2>/dev/null)
                DAY=$(echo $FORM | cut -d '#' -f 1)
                TIME=$(echo $FORM | cut -d '#' -f 2)
                AMOUNT=$(echo $FORM | cut -d '#' -f 3)
            fi

            case "$DAY" in
                1) DAY="Dni powszednie" ;;
                2) DAY="Soboty" ;;
                3) DAY="Niedziele i święta" ;;
                *) DAY="Dni powszednie" ;;
            esac

            TIME_NUMBER=$(echo $TIME | sed 's/://')

            LIST=$( \
                # download page source
                wget -O - -o /dev/null $LINK | \
                # START process source code to get a list in format HH:MM BusNumber
                tail -n 21 | \
                head -n 5 | \
                sed 's#</td><td></td></tr>#\n#g' | \
                sed 's#</b></a></td><td width="30%"># #' | \
                sed 's#</td><td width="50%"># #' | \
                sed 's#" class="block"><b># #' | \
                sed 's#</a></td><td align="center" width="10%"><a href="start-# #' | \
                sed 's#html"># #' | \
                sed 's#<tr><td align="center" width="10%"><a href="# #' | \
                sed 's#kurs#\n#g' | \
                # pass on only records form a specified DAY
                grep "$DAY" | \
                sed '/</d' | \
                cut -d ' ' -f 2,4 | \
                # END process source code...
                # change time format from HH:MM to HHMM (prepare for comparison with TIME)
                sed 's/://' | \
                # pass on only records with time >= specified TIME
                awk '$1 >= time' time="$TIME_NUMBER" | \
                # change time format from HHMM to HH:MM
                sed 's/\(..\)\(.*\)/\1:\2/' | \
                # pass on only first records in a specified AMOUNT 
                head -n $AMOUNT)

            if [ $ZENITY -eq 1 ]; then
                echo "$LIST" | \
                sed 's# #\t#g' | \
                zenity --text-info \
                    --title "Rozkład jazdy" \
                    2>/dev/null
            else
                echo "$LIST"
            fi
        ;;

        *) ESCAPE=1 ;;
    esac
done

