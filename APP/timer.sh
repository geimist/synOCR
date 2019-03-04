#!/bin/bash
# timer.sh
#right_timeplaner=1 # DEV: erzwungen, da nicht explizit hinterlegt / Prüfung evtl. löschen
timer_scriptname="/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh"


#if [[ "$right_timeplaner" == "1" ]]; then
	if [[ "$page" == "timer" ]]; then
		[ -f "$usersettings/timertmp.txt" ] && rm "$usersettings/timertmp.txt"
		[ -f "$var" ] && rm "$var"
	fi

	if [[ "$page" == "timer-set-4" ]]; then
		[ -n "$timer_frequenz" ] || echo 'Frequenz konnte nicht übertragen werden' >> "$stop"
	fi
	
	# Funktionen
	if [[ "$page" == "timer-set-3" ]]; then
		[ -f "$usersettings/timertmp.txt" ] && rm "$usersettings/timertmp.txt"
		IFS='
		'
		for i in "$@"; do
			IFS="$backifs"
			if [[ "$i" == timer_day* ]]; then
				i=$(echo "$i" | sed -e 's/.*timer_day=//g' | sed -f includes/decode.sed)
				echo "$i" >> "$usersettings/timertmp.txt"
			fi
		done
		if test -f "$usersettings/timertmp.txt"; then
			timer=$(cat "$usersettings/timertmp.txt")
			[ -f "$usersettings/timertmp.txt" ] && rm "$usersettings/timertmp.txt"
		fi
		timer=$(echo $timer | sed 's/ /,/g;s/7/0/g')
		sed -i "/$variable=/d" "$var"
		echo "timer=\"$timer\"" >> "$var"
		[ -n "$timer" ] || echo 'Es wurde kein Tag ausgewählt!' >> "$stop"
		[ -n "$timer_hour" ] || echo 'Es wurde keine Stunde ausgewählt!' >> "$stop"
		[ -n "$timer_minute" ] || echo 'Es wurde keine Minute ausgewählt!' >> "$stop"

		if [[ "$timer_times" == "one" ]]; then
			echo '<meta http-equiv="refresh" content="0; url=index.cgi?page=timer-set-5">'
		fi
	fi

	if [[ "$page" == "timer-delete-query" ]] || [[ "$page" == "timer-delete" ]]; then
		[ -f "$var" ] && rm "$var"
		if [[ "$page" == "timer-delete-query" ]]; then
			echo '
		    <p class="center" style="'$synotrred';">
				Soll der Cronjob wirklich entfernt werden?<br /><br /><b>'$(echo "$timer_scriptname" | sed 's/\\//g')'</b><br /><br /><br />
				<a href="index.cgi?page=timer-delete&timer_scriptname='$encode_timer_scriptname'" class="red_button">Ja</a>&nbsp;&nbsp;&nbsp;<a href="index.cgi?page=timer" class="button">Nein</a></p>'  >> "$stop"
		elif [[ "$page" == "timer-delete" ]]; then
			sed -i "/synOCR-start.sh/d" "/etc/crontab"; exit_delete=$?
			if [[ "$exit_delete" == "0" ]]; then
				echo '
					<p class="center" style="'$green';">Der Cronjob wurde gelöscht!<br /><br /><b>synOCR-start.sh</b><br /><br /><br /><a href="index.cgi?page=timer" class="blue_button">weiter</a><br>' >> "$stop"
			else
				echo '<p class="center" style="'$synotrred';">Der Cronjob konnte leider nicht gelöscht werden!<br /><br /><b>'$(echo "$timer_scriptname" | sed 's/\\//g')'</b><br /><br /><br /><a href="index.cgi?page=timer" class="button">weiter</a>' >> "$stop"
			fi
		fi
	elif [[ "$page" == "timer" ]]; then
		echo '
	    <div id="Content_1Col">
			<div class="Content_1Col_full">
    		    <div class="title">
    		        synOCR Zeitplaner
    		    </div>
			<p class="center">'
            i="/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh"
		echo '
			<button name="page" value="timer-set-1" class="blue_button">Neuer Zeitplan</button>
			</p>
			<br><br>
            <fieldset>'
		crontab=$(cat /etc/crontab | awk -F $'\t' 'NR > 1 {print $1 " " $2 " " $3 " " $4 " " $5 " " $6 " " $7 " " $8}' | sed 's/ $//' | grep -E 'synOCR-start.sh')
		if [ -n "$crontab" ]; then  # bei vorhandenem Zeitplan
			IFS="
			"
			croncount=0
			for i in $crontab; do
				IFS="$backifs"
				croncount=$(( croncount + 1 ))
				unset cron_minute cron_hour cron_day cron_scriptname encode_cron_scriptname dayname
				cron_minute=$(echo "$i" | awk '{print $1}')
				cron_hour=$(echo "$i" | awk '{print $2}')
				cron_day=$(echo "$i" | awk '{print $5}')
				timer_scriptname=$(echo "$i" | sed 's/ $//;s#.*/bin/bash ##')
				encode_timer_scriptname=$(echo "$timer_scriptname" | sed -f includes/encode.sed)
                            
                # Aufklappbar:
                echo '
                	<hr style="border-style: dashed; size: 1px;">
                	<br />
                    <details><p>
                    <summary>
                        <span class="detailsitem">Aktueller Croneintrag für synOCR</span>
                    </summary></p>
                        <p>
                
					<table>
					<tr><td class="left_25">Programmpfad</td><td>: <b style="'$grey'; font-weight: normal;"> '$(echo "$timer_scriptname" | sed 's/\\//g')'</b></td></tr>'
    				if [[ "$cron_day" == "*" ]]; then
    					echo '<tr><td class="left_25">Wochentag(e)</td><td>: <b style="'$grey'; font-weight: normal;"> Jeden Tag</b></td></tr>'
    				else
    					dayname=$(echo "$cron_day" | sed 's/,/, /g;s/1/Montag/g;s/2/Dienstag/g;s/3/Mittwoch/g;s/4/Donnerstag/g;s/5/Freitag/g;s/6/Samstag/g;s/0/Sonntag/g;')
    					echo '<tr><td class="left_25">Wochentag(e)</td><td>: <b style="'$grey'; font-weight: normal;"> '$dayname'</b></td></tr>'
    				fi
    				if [[ "$cron_hour" == *\/1 ]]; then
    					echo '
    						<tr><td class="left_25">Uhrzeit / Intervall</td><td>: <b style="'$grey'; font-weight: normal;"> von '$(echo "$cron_hour" | sed 's/-.*//;s#\(^[0-9]$\)#0\1#g')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' Uhr bis '$(echo "$cron_hour" | sed 's/.*-//;s/\/.*//')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' Uhr - stündlich </b></td></tr>'
    				elif [[ "$cron_hour" == *\/[2-9] ]] || [[ "$cron_hour" == *\/[1-2][0-3] ]]; then
    					echo '
    						<tr><td class="left_25">Uhrzeit und Intervall</td><td>: <b style="'$grey'; font-weight: normal;"> von '$(echo "$cron_hour" | sed 's/-.*//;s#\(^[0-9]$\)#0\1#g')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' Uhr bis '$(echo "$cron_hour" | sed 's/.*-//;s/\/.*//;s#\(^[0-9]$\)#0\1#g')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' Uhr - alle '$(echo "$cron_hour" | sed 's/.*\///')' Stunden </b></td></tr>'
    				else
    					echo '
    						<tr><td class="left_25">Uhrzeit</td><td>: <b style="'$grey'; font-weight: normal;"> um '"$(echo "$cron_hour" | sed 's#\(^[0-9]$\)#0\1#g')"':'"$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')"' Uhr</b></td></tr>'
    				fi
				echo '
					<tr><td class="left_25">Crontab</td><td>: <b style="'$grey'; font-weight: normal;"> '"$i"'</b></td></tr></table><br /><br />'
        		echo '
        		    <p class="center">
        		    <button name="page" class="red_button"><a href="index.cgi?page=timer-delete-query&timer_scriptname='$timer_scriptname'" style="color: white;">Löschen</a></button>
        		    &nbsp;&nbsp;</p>
                    </details></p><br>'
			done
			
			echo ' 
                <hr style="border-style: dashed; size: 1px;">
                </fieldset>
                </div>
			    </div>
			    
			    <div class="clear"></div>'
		fi
	fi

	if [[ "$timer_times" == "one" ]]; then
		unset checked_more
		checked_one="yes"
	elif [[ "$timer_times" == "more" ]]; then
		unset checked_one
		checked_more="yes"
	fi
	if [[ "$page" == timer-set-* ]]; then
		if [[ "$page" == "timer-set-1" ]]; then
			unset disable_times
		else
			disable_times="yes"
		fi
	fi

	if [[ "$page" == timer-set-* ]] && [[ "$page" != "timer-set-5" ]] && [[ "$page" != "timer-delete-query" ]] && [[ "$page" != "timer-delete" ]]; then
		echo '
			<div id="Content_1Col">
    			<div class="Content_1Col_full">
    			    <p>&nbsp;</p>
    			    <div class="title">Zeitplan einrichten</div>
        			<div class="info">
        			<h3>&raquo; 1. Wie oft soll synOCR pro Tag (pro Woche) ausgeführt werden?<br>
        			<span style="color: #BD0010;">INFO: Der DSM-Sicherheitsbereater wird den zusätzlichen Croneintrag (da für DSM unbekannt) bemängeln!</span></h3>
            			<div>
                			<div>
                			<input class="left" type="radio" id="radio-one" name="timer_times" value="one" '${checked_one:+checked}' '${disable_times:+disabled}'/>
                			<label class="left" style="width: 220px;" for="radio-one">Einmal am Tag</label>
                    			<div>
                    			<input class="left" type="radio" id="radio-more" name="timer_times" value="more" '${checked_more:+checked}' '${disable_times:+disabled}'/>
                    			<label class="left" style="width: 220px;" for="radio-more">Mehrmals am Tag</label>
                    			</div>
                			</div>
            			</div><br /><br />
        			</div>'
		
		echo '
			<div class="clear"></div>'
	fi

	if [[ "$page" == timer-set-* ]]; then
		if [[ "$page" == "timer-set-2" ]] || [[ "$page" == "timer-set-3" ]] || [[ "$page" == "timer-set-4" ]]; then
			if [[ "$timer_times" == "one" ]] || [[ "$timer_times" == "more" ]]; then
				echo '<br>
                <div class="divtable">
                    <div class="divtr">
                        <div class="divtd_left">
					        <div class="info">
					        <h3>&raquo; 2. An den folgenden Tagen ausführen:</h3>'
				tage=(1 2 3 4 5 6 0)
				for tag in ${tage[*]}; do
					unset found
					IFS=","
					for check in $timer; do
						IFS="$backifs"
						if [[ "$check" == "$tag" ]]; then
							found="yes"
						fi
					done
					if (( $tag == 1 )); then
						dayname='Montag'
					elif (( $tag == 2 )); then
						dayname='Dienstag'
					elif (( $tag == 3 )); then
						dayname='Mittwoch'
					elif (( $tag == 4 )); then
						dayname='Donnerstag'
					elif (( $tag == 5 )); then
						dayname='Freitag'
					elif (( $tag == 6 )); then
						dayname='Samstag'
					elif (( $tag == 0 )); then
						dayname='Sonntag'
					fi

					if [[ "$page" == "timer-set-2" ]]; then
						unset disable_day
						unset disable_time
						unset disable_time2
						unset disable_frequenz
					fi
					if [[ "$page" == "timer-set-3" ]] || [[ "$page" == "timer-set-4" ]] || [[ "$page" == "timer-set-5" ]]; then
						disable_day="yes"
						disable_time="yes"
					fi
					if [[ "$page" == "timer-set-4" ]] || [[ "$page" == "timer-set-5" ]]; then
						disable_time2="yes"
						disable_frequenz="yes"
					fi
					if [[ "$found" == "yes" ]]; then
						echo '
							<p class="left">
							<input class="left" type="checkbox" name="timer_day" value="'"$tag"'" id="'"$dayname"'" checked '${disable_day:+disabled}'>
							<label class="left" for="'"$dayname"'">'"$dayname"'</label><br />
							</p>'
					else
						echo '
							<p class="left">
							<input class="left" type="checkbox" name="timer_day" value="'"$tag"'" id="'"$dayname"'" '${disable_day:+disabled}'>
							<label class="left" for="'"$dayname"'">'"$dayname"'</label><br />
							</p>'
					fi
				done
				echo '
					<p>&nbsp;</p><br />
					</div>
                    </div>
                    <div class="divtd_mid"></div>
                    <div class="divtd_right">
					<div class="info">'
				if [[ "$timer_times" != "more" ]]; then
					echo '<h3>&raquo; 3. Ausführungszeit:</h3>'
				else
					echo '<h3>&raquo; 3. Ausführungszeit von:</h3>'
				fi
				echo '
					<p><select name="timer_hour" style="width: 100px;">
					<option selected="selected" value="" disabled>Stunde</option>'
				set_hour=0
				while [ $set_hour -le 23 ]; do
					show_hour=$(echo "$set_hour" | sed 's#\(^[0-9]$\)#0\1#g')
					if [[ $set_hour == $timer_hour ]]; then
						echo '<option value="'$set_hour'" selected '${disable_time:+disabled}'>'$show_hour'</option>'
					else
						echo '<option value="'$set_hour'" '${disable_time:+disabled}'>'$show_hour'</option>'
					fi
					set_hour=`expr $set_hour + 1`
				done
				echo '
					</select>&nbsp;&nbsp;:
					<select name="timer_minute" style="width: 100px;">
					<option selected="selected" value="" disabled>Minute</option>'
				set_minute=0
				while [ $set_minute -le 59 ]; do
					show_minute=$(echo "$set_minute" | sed 's#\(^[0-9]$\)#0\1#g')
					if [[ $set_minute == $timer_minute ]]; then
						echo '<option value="'$set_minute'" selected '${disable_time:+disabled}'>'$show_minute'</option>'
					else
						echo '<option value="'$set_minute'" '${disable_time:+disabled}'>'$show_minute'</option>'
					fi
					set_minute=`expr $set_minute + 1`
	  		done
	  		
			echo '</select></p>'

			if [[ "$timer_times" == "more" ]]; then
				if [[ "$page" == "timer-set-3" ]] || [[ "$page" == "timer-set-4" ]]; then
					bc_minute=$(gawk '{print $0/6*10}' <<< $timer_minute | sed 's/\..*//;s/^0$/00/')
					bc_minus="$timer_hour$bc_minute"
					bc_diff=$((2359-bc_minus))
					bc_max=$(echo "$bc_diff" | sed 's/[0-9][0-9]$//')
					bc_x=$((bc_max+1))
					echo '
						<h3>&raquo; 4. Anzahl der Wiederholungen:</h3>
						<p><select name="timer_frequenz" style="width: 228px;">
						<option selected="selected" value="" disabled>Frequenz</option>
						<option selected="selected" value="1" '${disable_frequenz:+disabled}'>Jede Stunde</option>'
						
                        # weitere Frequenzen fehlen noch:
						# <option selected="selected" value="1" '${disable_frequenz:+disabled}'>Jede Minute</option>

						set_frequency=2
					while [ $set_frequency -le $bc_max ]; do
						unset bc_x
						bc_x=$((bc_max/set_frequency+1))
						bc_end=$((bc_x-1))
						bc_end=$((bc_end*set_frequency))
						bc_end=$((bc_end+timer_hour))
						if [[ $set_frequency == $timer_frequenz ]]; then
							bc_z="$bc_end"
							echo '<option value="'$set_frequency'" selected '${disable_frequenz:+disabled}'>alle '$set_frequency' Stunden</option>'
						else
							echo '<option value="'$set_frequency'" '${disable_frequenz:+disabled}'>alle '$set_frequency' Stunden</option>'
						fi
						set_frequency=`expr $set_frequency + 1`
					done
					echo '</select>'
				fi
			fi

			if [[ "$timer_times" == "more" ]] && [[ "$page" == "timer-set-4" ]]; then
				echo '
					<h3>&raquo; 5. Ausführungszeit bis:</h3>
					<p><select name="timer_to_hour" style="width: 100px;">
					<option selected="selected" value="" disabled>Stunde</option>'
				set_hour=$((timer_hour+timer_frequenz))
				while [ $set_hour -le 23 ]; do
					show_hour=$(echo "$set_hour" | sed 's#\(^[0-9]$\)#0\1#g')
					if (( $set_hour == $bc_z )); then
						echo '<option value="'$set_hour'" selected >'$show_hour'</option>'
					else
						echo '<option value="'$set_hour'" >'$show_hour'</option>'
					fi
					set_hour=`expr $set_hour + $timer_frequenz`
				done
				show_minute=$(echo "$timer_minute" | sed 's#\(^[0-9]$\)#0\1#g')
				echo '
					</select>&nbsp;&nbsp;:
					<select name="timer_to_minute" style="width: 100px;">
					<option selected="selected" value="'$timer_minute'" disabled>Minute</option>
					<option selected="selected" value="'$timer_minute'" selected>'$show_minute'</option>
					</select></p><br />'
			fi
			echo '
                    </div>
                	</div>
                </div>	
			    </div>
			</div>
			<div class="clear"></div>'
		else
			echo 'treffe bitte eine Auswahl!' >> "$stop"
		fi

		elif [[ "$page" == "timer-set-5" ]]; then
			dayname=$(echo $timer | sed 's/,/, /g;s/1/Montag/g;s/2/Dienstag/g;s/3/Mittwoch/g;s/4/Donnerstag/g;s/5/Freitag/g;s/6/Samstag/g;s/0/Sonntag/g;')
			show_hour=$(echo "$timer_hour" | sed 's#\(^[0-9]$\)#0\1#g')
			show_to_hour=$(echo "$timer_to_hour" | sed 's#\(^[0-9]$\)#0\1#g')
			show_minute=$(echo "$timer_minute" | sed 's#\(^[0-9]$\)#0\1#g')
			[ -n "$timer_scriptname" ] || echo 'Scriptname konnte nicht übertragen werden' >> "$stop"
			[ -n "$dayname" ] || echo 'Dayname konnte nicht übertragen werden' >> "$stop"
			[ -n "$timer_hour" ] || echo 'Stunde konnte nicht übertragen werden' >> "$stop"
			[ -n "$timer_minute" ] || echo 'Minute konnte nicht übertragen werden' >> "$stop"
			if [[ "$timer_times" == "more" ]]; then
				[ -n "$timer_to_hour" ] || echo 'Stunde -bis- konnte nicht übertragen werden' >> "$stop"
				[ -n "$timer_frequenz" ] || echo 'Frequenz konnte nicht übertragen werden' >> "$stop"
			fi
			if [ ! -f "$stop" ]; then
			echo '
				<div id="Content_1Col">
				<div class="Content_1Col_full"><p>&nbsp;</p>
				<h2>Folgende Daten werden übernommen...</h2>
				<br><div class="info"><p class="center">Das Script <b>'"$timer_scriptname"'</b><br /><br />wird am <b>'"$dayname"'</b> '
			if [[ "$timer_times" != "more" ]]; then
				echo 'um <b>'$show_hour':'$show_minute' Uhr</b> ausgeführt!<br /><br />'
			else
				echo '<br /><br />in der Zeit von <b>'$show_hour':'$show_minute' Uhr</b> bis <b>'$show_to_hour':'$show_minute' Uhr</b>, '
			if [ -n "$timer_frequenz" ]; then
				if (( $timer_frequenz == 1 )); then
					echo '<b>stündlich</b> ausgeführt!<br /><br />'
				else
					echo '<b>alle '$timer_frequenz' Stunden</b> ausgeführt!<br /><br />'
				fi
			fi
		fi

		echo '</p><br /></div></div><div class="clear"></div>'
		if [ -n "$timer_to_hour" ]; then
			timer_to_hour="-$timer_to_hour"
		fi
		if [ -n "$timer_frequenz" ]; then
			timer_frequenz="/$timer_frequenz"
		fi
		
		echo '
			<div class="Content_1Col_full"><p>&nbsp;</p>
			<div class="info"><p class="center"><b>Folgender Eintrag wird an CRONTAB übergeben:</b><br /><br />
			'$timer_minute $timer_hour$timer_to_hour$timer_frequenz' * * '$timer'</p></div></div></div><div class="clear"></div>'
			fi
		elif [[ "$page" == "timer-set-6" ]]; then
			dayname=$(echo $timer | sed 's/,/, /g;s/1/Montag/g;s/2/Dienstag/g;s/3/Mittwoch/g;s/4/Donnerstag/g;s/5/Freitag/g;s/6/Samstag/g;s/0/Sonntag/g;')
			if [ -n "$timer_to_hour" ]; then
				timer_to_hour="-$timer_to_hour"
			fi
			if [ -n "$timer_frequenz" ]; then
				timer_frequenz="/$timer_frequenz"
			fi
			timer_delete=$(echo "$timer_scriptname" | sed 's/.*\///g')
			timer_scriptname_escape=$(echo "$timer_scriptname" | sed 's/ /\\ /g')
			sed -i "/"$timer_delete"/d" "/etc/crontab"
			echo -e "$timer_minute\t$timer_hour$timer_to_hour$timer_frequenz\t*\t*\t$timer\troot\t/bin/bash "$timer_scriptname_escape"" >> /etc/crontab

            echo -e "$timer_minute\t$timer_hour$timer_to_hour$timer_frequenz\t*\t*\t$timer\troot\t/bin/bash "$timer_scriptname_escape"" >> "$usersettings/timertmp.txt"

			echo '<meta http-equiv="refresh" content="0; url=index.cgi?page=timer">'
		fi
	fi
#fi