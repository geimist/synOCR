#!/bin/bash
# /usr/syno/synoman/webman/3rdparty/synOCR/timer.sh
#right_timeplaner=1 # DEV: erzwungen, da nicht explizit hinterlegt / Prüfung evtl. löschen
timer_scriptname="/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh"


#if [[ "$right_timeplaner" == "1" ]]; then
	if [[ "$page" == "timer" ]]; then
		[ -f "$usersettings/timertmp.txt" ] && rm "$usersettings/timertmp.txt"
		[ -f "$var" ] && rm "$var"
	fi

	if [[ "$page" == "timer-set-4" ]]; then
		[ -n "$timer_frequenz" ] || echo "$lang_timer_set4" >> "$stop"
	fi
	
	# Funktionen
	if [[ "$page" == "timer-set-3" ]]; then
		[ -f "$usersettings/timertmp.txt" ] && rm "$usersettings/timertmp.txt"
		IFS='
		'
		for i in "$@"; do
			IFS="$backifs"
			if [[ "$i" == timer_day* ]]; then
				i=$(echo "$i" | sed -e 's/.*timer_day=//g' | sed -f ./includes/decode.sed)
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
		[ -n "$timer" ] || echo "$lang_timer_set3_1" >> "$stop"
		[ -n "$timer_hour" ] || echo "$lang_timer_set3_2" >> "$stop"
		[ -n "$timer_minute" ] || echo "$lang_timer_set3_3" >> "$stop"

		if [[ "$timer_times" == "one" ]]; then
			echo '<meta http-equiv="refresh" content="0; url=index.cgi?page=timer-set-5">'
		fi
	fi

	if [[ "$page" == "timer-delete-query" ]] || [[ "$page" == "timer-delete" ]]; then
		[ -f "$var" ] && rm "$var"
		if [[ "$page" == "timer-delete-query" ]]; then
			echo '
		    <p class="center" style="'$synocrred';">'$lang_timer_delete_1'<br /><br /><b>'$(echo "$timer_scriptname" | sed 's/\\//g')'</b><br /><br /><br />
				<a href="index.cgi?page=timer-delete&timer_scriptname='$encode_timer_scriptname'" class="red_button">'$lang_yes'</a>&nbsp;&nbsp;&nbsp;<a href="index.cgi?page=timer" class="button">'$lang_no'</a></p>'  >> "$stop"
		elif [[ "$page" == "timer-delete" ]]; then
			sed -i "/synOCR-start.sh/d" "/etc/crontab"; exit_delete=$?
			if [[ "$exit_delete" == "0" ]]; then
				echo '
					<p class="center" style="'$green';">'$lang_timer_delete_2'<br /><br /><b>synOCR-start.sh</b><br /><br /><br /><a href="index.cgi?page=timer" class="blue_button">'$lang_buttonnext'</a><br>' >> "$stop"
			else
				echo '<p class="center" style="'$synocrred';">'$lang_timer_delete_3'<br /><br /><b>'$(echo "$timer_scriptname" | sed 's/\\//g')'</b><br /><br /><br /><a href="index.cgi?page=timer" class="button">'$lang_buttonnext'</a>' >> "$stop"
			fi
		fi
	elif [[ "$page" == "timer" ]]; then
		echo '
	    <div id="Content_1Col">
			<div class="Content_1Col_full">
    		    <div class="title">synOCR '$lang_page3'</div><p class="center">'
            i="/usr/syno/synoman/webman/3rdparty/synOCR/synOCR-start.sh"
		echo '
			<button name="page" value="timer-set-1" class="blue_button">'$lang_timer_button_new'</button></p><br><br>
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
				encode_timer_scriptname=$(echo "$timer_scriptname" | sed -f ./includes/encode.sed)
                            
                # Aufklappbar:
                echo '
                	<hr style="border-style: dashed; size: 1px;">
                	<br />
                    <details><p>
                    <summary>
                        <span class="detailsitem">'$lang_timer_currentcron_title'</span>
                    </summary></p>
                        <p>
                
					<table>
					<tr><td class="left_25">'$lang_timer_currentcron_sub1'</td><td>: <b style="'$grey'; font-weight: normal;"> '$(echo "$timer_scriptname" | sed 's/\\//g')'</b></td></tr>'
    				if [[ "$cron_day" == "*" ]]; then
    					echo '<tr><td class="left_25">'$lang_timer_currentcron_sub2'</td><td>: <b style="'$grey'; font-weight: normal;"> '$lang_timer_everyday'</b></td></tr>'
    				else
    					dayname=$(echo "$cron_day" | sed 's/,/, /g;s/1/'$lang_timer_monday'/g;s/2/'$lang_timer_tuesday'/g;s/3/'$lang_timer_wednesday'/g;s/4/'$lang_timer_thursday'/g;s/5/'$lang_timer_friday'/g;s/6/'$lang_timer_saturday'/g;s/0/'$lang_timer_sunday'/g;')
    					echo '<tr><td class="left_25">'$lang_timer_currentcron_sub2'</td><td>: <b style="'$grey'; font-weight: normal;"> '$dayname'</b></td></tr>'
    				fi
    				if [[ "$cron_hour" == *\/1 ]]; then
    					echo '
    						<tr><td class="left_25">'$lang_timer_time' / '$lang_timer_interval'</td><td>: <b style="'$grey'; font-weight: normal;"> '$lang_timer_from' '$(echo "$cron_hour" | sed 's/-.*//;s#\(^[0-9]$\)#0\1#g')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' '$lang_timer_oclock' '$lang_timer_up2' '$(echo "$cron_hour" | sed 's/.*-//;s/\/.*//')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' '$lang_timer_oclock' - '$lang_timer_hourly' </b></td></tr>'
    				elif [[ "$cron_hour" == *\/[2-9] ]] || [[ "$cron_hour" == *\/[1-2][0-3] ]]; then
    					echo '
    						<tr><td class="left_25">'$lang_timer_time' '$lang_and' '$lang_timer_interval'</td><td>: <b style="'$grey'; font-weight: normal;"> '$lang_timer_from' '$(echo "$cron_hour" | sed 's/-.*//;s#\(^[0-9]$\)#0\1#g')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' '$lang_timer_oclock' '$lang_timer_up2' '$(echo "$cron_hour" | sed 's/.*-//;s/\/.*//;s#\(^[0-9]$\)#0\1#g')':'$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')' '$lang_timer_oclock' - '$lang_timer_all' '$(echo "$cron_hour" | sed 's/.*\///')' '$lang_timer_houres' </b></td></tr>'
    				else
    					echo '
    						<tr><td class="left_25">'$lang_timer_time'</td><td>: <b style="'$grey'; font-weight: normal;"> '$lang_timer_at' '"$(echo "$cron_hour" | sed 's#\(^[0-9]$\)#0\1#g')"':'"$(echo "$cron_minute" | sed 's#\(^[0-9]$\)#0\1#g')"' '$lang_timer_oclock'</b></td></tr>'
    				fi
				echo '
					<tr><td class="left_25">'$lang_timer_crontab'</td><td>: <b style="'$grey'; font-weight: normal;"> '"$i"'</b></td></tr></table><br /><br />'
        		echo '
        		    <p class="center">
        		    <button name="page" class="red_button"><a href="index.cgi?page=timer-delete-query&timer_scriptname='$timer_scriptname'" style="color: white;">'$lang_delete'</a></button>
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
    			    <div class="title">'$lang_timer_create_title'</div>
        			<div class="info">
        			<h3>&raquo; 1. '$lang_timer_create_set1_1'<br>
        			<span style="color: #BD0010;">'$lang_timer_create_securitywarn'</span></h3>
            			<div>
                			<div>
                			<input class="left" type="radio" id="radio-one" name="timer_times" value="one" '${checked_one:+checked}' '${disable_times:+disabled}'/>
                			<label class="left" style="width: 220px;" for="radio-one">'$lang_timer_create_set1_1xday'</label>
                    			<div>
                    			<input class="left" type="radio" id="radio-more" name="timer_times" value="more" '${checked_more:+checked}' '${disable_times:+disabled}'/>
                    			<label class="left" style="width: 220px;" for="radio-more">'$lang_timer_create_set1_Xxday'</label>
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
					        <h3>&raquo; 2. '$lang_timer_create_set2_1':</h3>'
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
						dayname=$lang_timer_monday
					elif (( $tag == 2 )); then
						dayname=$lang_timer_tuesday
					elif (( $tag == 3 )); then
						dayname=$lang_timer_wednesday
					elif (( $tag == 4 )); then
						dayname=$lang_timer_thursday
					elif (( $tag == 5 )); then
						dayname=$lang_timer_friday
					elif (( $tag == 6 )); then
						dayname=$lang_timer_saturday
					elif (( $tag == 0 )); then
						dayname=$lang_timer_sunday
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
					echo '<h3>&raquo; 3. '$lang_timer_create_set3_1':</h3>'
				else
					echo '<h3>&raquo; 3. '$lang_timer_create_set3_1' '$lang_timer_from':</h3>'
				fi
				echo '
					<p><select name="timer_hour" style="width: 100px;">
					<option selected="selected" value="" disabled>'$lang_timer_houre'</option>'
				set_hour=0
				while [ $set_hour -le 23 ]; do
					show_hour=$(echo "$set_hour" | sed 's#\(^[0-9]$\)#0\1#g')
					if [[ $set_hour == $timer_hour ]]; then
						echo '<option value="'$set_hour'" selected '${disable_time:+disabled}'>'$show_hour'</option>'
					else
						echo '<option value="'$set_hour'" '${disable_time:+disabled}'>'$show_hour'</option>'
					fi
					set_hour=$(( $set_hour + 1 ))
				done
				echo '
					</select>&nbsp;&nbsp;:
					<select name="timer_minute" style="width: 100px;">
					<option selected="selected" value="" disabled>'$lang_timer_minute'</option>'
				set_minute=0
				while [ $set_minute -le 59 ]; do
					show_minute=$(echo "$set_minute" | sed 's#\(^[0-9]$\)#0\1#g')
					if [[ $set_minute == $timer_minute ]]; then
						echo '<option value="'$set_minute'" selected '${disable_time:+disabled}'>'$show_minute'</option>'
					else
						echo '<option value="'$set_minute'" '${disable_time:+disabled}'>'$show_minute'</option>'
					fi
					set_minute=$(( $set_minute + 1 ))
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
						<h3>&raquo; 4. '$lang_timer_create_set4_1':</h3>
						<p><select name="timer_frequenz" style="width: 228px;">
						<option selected="selected" value="" disabled>'$lang_timer_freq'</option>
						<option selected="selected" value="1" '${disable_frequenz:+disabled}'>'$lang_timer_everyhoure'</option>'
						
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
							echo '<option value="'$set_frequency'" selected '${disable_frequenz:+disabled}'>'$lang_timer_all' '$set_frequency' '$lang_timer_houres'</option>'
						else
							echo '<option value="'$set_frequency'" '${disable_frequenz:+disabled}'>'$lang_timer_all' '$set_frequency' '$lang_timer_houres'</option>'
						fi
						set_frequency=$(( $set_frequency + 1 ))
					done
					echo '</select>'
				fi
			fi

			if [[ "$timer_times" == "more" ]] && [[ "$page" == "timer-set-4" ]]; then
				echo '
					<h3>&raquo; 5. '$lang_timer_create_set3_1' '$lang_timer_up2':</h3>
					<p><select name="timer_to_hour" style="width: 100px;">
					<option selected="selected" value="" disabled>'$lang_timer_houre'</option>'
				set_hour=$((timer_hour+timer_frequenz))
				while [ $set_hour -le 23 ]; do
					show_hour=$(echo "$set_hour" | sed 's#\(^[0-9]$\)#0\1#g')
					if (( $set_hour == $bc_z )); then
						echo '<option value="'$set_hour'" selected >'$show_hour'</option>'
					else
						echo '<option value="'$set_hour'" >'$show_hour'</option>'
					fi
					set_hour=$(( $set_hour + $timer_frequenz ))
				done
				show_minute=$(echo "$timer_minute" | sed 's#\(^[0-9]$\)#0\1#g')
				echo '
					</select>&nbsp;&nbsp;:
					<select name="timer_to_minute" style="width: 100px;">
					<option selected="selected" value="'$timer_minute'" disabled>'$lang_timer_minute'</option>
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
			echo $lang_timer_create_set4_2 >> "$stop"
		fi

		elif [[ "$page" == "timer-set-5" ]]; then
			dayname=$(echo $timer | sed 's/,/, /g;s/1/'$lang_timer_monday'/g;s/2/'$lang_timer_tuesday'/g;s/3/'$lang_timer_wednesday'/g;s/4/'$lang_timer_thursday'/g;s/5/'$lang_timer_friday'/g;s/6/'$lang_timer_saturday'/g;s/0/'$lang_timer_sunday'/g;')
			show_hour=$(echo "$timer_hour" | sed 's#\(^[0-9]$\)#0\1#g')
			show_to_hour=$(echo "$timer_to_hour" | sed 's#\(^[0-9]$\)#0\1#g')
			show_minute=$(echo "$timer_minute" | sed 's#\(^[0-9]$\)#0\1#g')
			[ -n "$timer_scriptname" ] || echo $lang_timer_create_set5_1 >> "$stop"
			[ -n "$dayname" ] || echo $lang_timer_create_set5_2 >> "$stop"
			[ -n "$timer_hour" ] || echo $lang_timer_create_set5_3 >> "$stop"
			[ -n "$timer_minute" ] || echo $lang_timer_create_set5_4 >> "$stop"
			if [[ "$timer_times" == "more" ]]; then
				[ -n "$timer_to_hour" ] || echo $lang_timer_create_set5_5 >> "$stop"
				[ -n "$timer_frequenz" ] || echo $lang_timer_create_set5_6 >> "$stop"
			fi
			if [ ! -f "$stop" ]; then
			echo '
				<div id="Content_1Col">
				<div class="Content_1Col_full"><p>&nbsp;</p>
				<h2>'$lang_timer_create_set5_7'</h2>
				<br><div class="info"><p class="center">'$lang_timer_create_set5_7a' <b>'"$timer_scriptname"'</b><br /><br />'$lang_timer_create_set5_7b' <b>'"$dayname"'</b> '
			if [[ "$timer_times" != "more" ]]; then
				echo $lang_timer_at' <b>'$show_hour':'$show_minute' '$lang_timer_oclock'</b> '$lang_timer_create_set5_7c'!<br /><br />'
			else
				echo '<br /><br />'$lang_timer_create_set5_7d' <b>'$show_hour':'$show_minute' '$lang_timer_oclock'</b> '$lang_timer_up2' <b>'$show_to_hour':'$show_minute' '$lang_timer_oclock'</b>, '
			if [ -n "$timer_frequenz" ]; then
				if (( $timer_frequenz == 1 )); then
					echo '<b>'$lang_timer_hourly'</b> '$lang_timer_create_set5_7c'!<br /><br />'
				else
					echo '<b>'$lang_timer_all' '$timer_frequenz' '$lang_timer_houres'</b> '$lang_timer_create_set5_7c'!<br /><br />'
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
			<div class="info"><p class="center"><b>'$lang_timer_create_result':</b><br /><br />
			'$timer_minute $timer_hour$timer_to_hour$timer_frequenz' * * '$timer'</p></div></div></div><div class="clear"></div>'
			fi
		elif [[ "$page" == "timer-set-6" ]]; then
			dayname=$(echo $timer | sed 's/,/, /g;s/1/'$lang_timer_monday'/g;s/2/'$lang_timer_tuesday'/g;s/3/'$lang_timer_wednesday'/g;s/4/'$lang_timer_thursday'/g;s/5/'$lang_timer_friday'/g;s/6/'$lang_timer_saturday'/g;s/0/'$lang_timer_sunday'/g;')
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
