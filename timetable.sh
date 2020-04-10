#!/bin/bash

LINK="https://komunikacja.tczew.pl/chrono.php?stop_id=27&cs=003_20200316-17-2--007_20200316-31-1"
DAY=Dni # Dni or Soboty or Niedziele
TIME="1:00"
AMOUNT=1000

TIMENUMBER=$(echo $TIME | sed 's/://')


LIST=$( \
wget -O - -o /dev/null $LINK | \ # download page source
tail -n 21 | \ # START process source code to get a list in format HH:MM BusNumber
head -n 5 | \
sed 's#</td><td></td></tr>#\n#g' | \
sed 's#</b></a></td><td width="30%"># #' | \
sed 's#</td><td width="50%"># #' | \
sed 's#" class="block"><b># #' | \
sed 's#</a></td><td align="center" width="10%"><a href="start-# #' | \
sed 's#html"># #' | \
sed 's#<tr><td align="center" width="10%"><a href="# #' | \
sed 's#kurs#\n#g' | \
grep "$DAY" | \ # pass on only records form a specified DAY
sed '/</d' | \
cut -d ' ' -f 2,4 | \ # END process...
sed 's/://' | \ # change time format from HH:MM to HHMM (prepare for comparison with TIME)
awk '$1 >= time' time="$TIMENUMBER" | \ # pass on only records with time >= specified TIME
sed 's/\(..\)\(.*\)/\1:\2/' | \ # change time format from HHMM to HH:MM
head -n $AMOUNT \ # pass on only first records in amount of specified AMOUNT 
)

echo "$LIST"
