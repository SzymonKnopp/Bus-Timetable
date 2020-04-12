#!/bin/bash

# DO USUNIĘCIA PÓŹNIEJ!!!
LINK="https://komunikacja.tczew.pl/chrono.php?stop_id=27&cs=003_20200316-17-2--007_20200316-31-1"
DAY=Dni # Dni or Soboty or Niedziele
TIME="1:00"
AMOUNT=1000

FAVORITES=favorites # path to a file containing saved data

#PROCESS OPTIONS
ZENITY=0
while [ -n "$1" ]; do
    ZENITY=1
    case "$1" in
        -p) 
            echo "Option -p argument: $2"
            shift ;;
        -c) 
            echo "Option -c argument: $2"
            shift ;;
        
    esac
    shift



done




ESCAPE=0
until [ $ESCAPE -eq 1 ]; do
    FAV_LIST=$(cat favorites | cut -d "#" -f 1)

    FUNCTION=$(zenity --entry \
        --title "Rozkład jazdy" \
        --text "Co chcesz zrobić?\n\n1. Znajdź autobusy\n2. Dodaj rozkład jazdy\n3. Usuń rozkład jazdy\n4. Zakończ działanie" \
        --width 200 \
        2>/dev/null) # redirecting stderr to null to remove warning from terminal

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
                --width 300
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
                --width 300
                2>/dev/null
        ;;


        1) #GET BUSES
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

            echo "$LIST" | \
            sed 's# #\t#g' | \
            zenity --text-info \
                --title "Rozkład jazdy" \
        ;;

        *) ESCAPE=1 ;;
    esac
done

