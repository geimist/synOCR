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
				<button name="page" value="timer">'$lang_buttonback'</button>&nbsp;&nbsp;&nbsp;'
			elif [[ "$page" == "timer-set-5" ]] && [[ "$timer_times" == "one" ]]; then
				echo '
				<button name="page" value="timer-set-2">'$lang_buttonback'</button>&nbsp;&nbsp;&nbsp;'
			else
				echo '
				<button name="page" value="timer-set-'$siteless'">'$lang_buttonback'</button>&nbsp;&nbsp;&nbsp;'
			fi
			if [[ "$page" == "timer-set-5" ]]; then
				echo '
				<button name="page" value="timer-set-6"  class="blue_button">'$lang_foot_buttonsavetimer'</button>'
			else
				echo '
				<button name="page" value="timer-set-'$sitemore'">'$lang_buttonnext'</button>'
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
	    <button name="page" value="edit-save" class="blue_button">'$lang_buttonsave'</button>&nbsp;
	    <button name="page" value="edit-new_profile-query">'$lang_foot_buttonnewprofile'</button>&nbsp;
	    <button name="page" value="edit-dup-profile-query" title="'$lang_foot_buttoncloneprof_tit'">'$lang_foot_buttoncloneprof'</button>&nbsp; 
	    <button name="page"><a href="etc/synOCR.sqlite" download="synOCR.sqlite" title="'$lang_foot_buttondownDB_tit'">'$lang_foot_buttondownDB'</a></button>&nbsp;
	    <button name="page" value="edit-del_profile-query" class="red_button" title="'$lang_foot_buttondelprof_tit'">'$lang_foot_buttondelprof'</button>&nbsp;
	    </div>'
    echo '
        </p>
        </footer>'
	echo '
		<div class="clear"></div>'
fi
