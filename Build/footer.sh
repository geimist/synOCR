#!/bin/bash
# footer.sh

if [[ "$mainpage" == "timer" ]]; then
	echo '
	    <footer>
		<p class="center">'
	
	if [[ "$page" != "timer" ]] && [[ "$page" != "timer-set-6" ]] && [[ "$page" != "timer-delete-query" ]] && [[ "$page" != "timer-delete" ]]; then
		if [[ "$page" == timer-* ]]; then
			if [[ "$page" == "timer-set-1" ]]; then
				echo '
				<button name="page" value="timer">zurück</button>&nbsp;&nbsp;&nbsp;'
			elif [[ "$page" == "timer-set-5" ]] && [[ "$timer_times" == "one" ]]; then
				echo '
				<button name="page" value="timer-set-2">zurück</button>&nbsp;&nbsp;&nbsp;'
			else
				echo '
				<button name="page" value="timer-set-'$siteless'">zurück</button>&nbsp;&nbsp;&nbsp;'
			fi
			if [[ "$page" == "timer-set-5" ]]; then
				echo '
				<button name="page" value="timer-set-6"  class="blue_button">Zeitplan speichern</button>'
			else
				echo '
				<button name="page" value="timer-set-'$sitemore'">weiter</button>'
			fi
		fi
	fi

	echo '
        </p>
        </footer>
		<div class="clear"></div>'
		
elif [[ "$mainpage" == "edit" ]]; then
	echo '
	    <footer>
        <p>'
		# button:
	echo '
		<div style="text-align: right;">
	    <button name="page" value="edit-save" class="blue_button">Speichern</button>&nbsp;
	    <button name="page" value="edit-import-query">Import</button>&nbsp;
	    <button name="page" value="edit-export">Export</button>&nbsp;
	    <button name="page"><a href="etc/Konfiguration.txt" download="Konfiguration.txt">Download</a></button>&nbsp;
	    <button name="page" value="edit-restore-query" class="red_button">R E S E T</button>&nbsp;
	    </div>'
    echo '
        </p>
        </footer>'
	echo '
		<div class="clear"></div>'
fi