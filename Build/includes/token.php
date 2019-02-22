<?php require('includes/check_privilege.inc.php'); list($synotoken,
$synouser, $is_admin) =
check_privilege('SYNO.SDS.synOCR.Application'); if ($synouser == '')
	{
		echo "0";
	}
else
	{
		echo "token: $synotoken user: $synouser admin: $is_admin";
	}
?>
