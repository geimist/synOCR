<?PHP
//***********************************************************************//
//  check_appprivilege.inc.php                                               //
//  Description: Script to query the active user permission for the      //
//               called application.                                     //
//               This will allow control of the permissions for          //
//               3rdparty apps via Control Panel - Permissions           //
//               Now with query from SynoToken (DSM 4.x and onward)      //
//  Author:      QTip from the german Synology support forum             //
//  Copyright:   2014-2016 by QTip                                       //
//  License:     GNU GPLv3 (see LICENSE)                                 //
//  Thanks to MrSandman (German Synology support forum) for the nudge in //
//  the right direction                                                  //
//  -------------------------------------------------------------------  //
//  Version:     0.31 - 18/09/2016                                       //
//***********************************************************************//
function check_privilege($appname) {
     if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])){
          $clientIP = $_SERVER['HTTP_X_FORWARDED_FOR'];
     } elseif (isset($_SERVER['HTTP_X_REAL_IP'])){
          $clientIP = $_SERVER['HTTP_X_REAL_IP'];
     } else {
          $clientIP = $_SERVER['REMOTE_ADDR'];
     }
     putenv('HTTP_COOKIE='.$_SERVER['HTTP_COOKIE']);
     putenv('REMOTE_ADDR='.$clientIP);
     $login = shell_exec("/usr/syno/synoman/webman/login.cgi");
     preg_match('/\"SynoToken\"\s*?:\s*?\"(.*)\"/',$login,$synotoken);
     $synotoken = trim($synotoken[1]);
     // backup the current state of QUERY_STRING
     $tmpenv = getenv('QUERY_STRING');
     putenv('QUERY_STRING=SynoToken='.$synotoken);
     $synouser = shell_exec("/usr/syno/synoman/webman/modules/authenticate.cgi");
     if ($synouser == '') return array('','',0);

     // get dsm build
     $dsmbuild = shell_exec("/bin/get_key_value /etc.defaults/VERSION buildnumber");
     if ($dsmbuild >= 7307) {
          $raw_data = shell_exec("/usr/syno/bin/synowebapi --exec api=SYNO.Core.Desktop.Initdata method=get version=1 runner=".$synouser);
          $initdata = json_decode(trim($raw_data),true);
          $appprivilege = (array_key_exists($appname, $initdata['data']['AppPrivilege']) && $initdata['data']['AppPrivilege'][$appname]) ? 1 : 0;
          $is_admin = (array_key_exists('is_admin', $initdata['data']['Session']) && $initdata['data']['Session']['is_admin'] == 1) ? 1 : 0;
     } else {
          $raw_data = shell_exec("/usr/syno/synoman/webman/initdata.cgi");
          $raw_data = substr($raw_data,strpos($raw_data,"{")-1);
          $initdata = json_decode(trim($raw_data),true);
          $appprivilege = (array_key_exists($appname, $initdata['AppPrivilege']) && $initdata['AppPrivilege'][$appname]) ? 1 : 0;
          $is_admin = (array_key_exists('is_admin', $initdata['Session']) && $initdata['Session']['is_admin'] == 1) ? 1 : 0;
     }
     // print $synotoken." - ".$synouser." - ".$is_admin;
     // if application not found or user not admin, return empty string
     // restore the old state of QUERY_STRING
     putenv('QUERY_STRING='.$tmpenv);
     if (!$appprivilege && !$is_admin) return array('','',0);
     return array($synotoken,$synouser,$is_admin);
}
?>

