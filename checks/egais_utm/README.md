# egais_utm check
Checks status of Egais Utm server on which the agent is run. Only Windows agent is supported ATM.

The check requires pytz module installed on Check_MK server. The agent requires [HtmlAgilityPack](https://github.com/zzzprojects/html-agility-pack) 
dll in MK_ROOT folder (usually C:\Program Files (x86)\check_mk\\).

To install the check copy the following to your Check_MK server:
* ./checks/egais_utm => /omd/sites/*site_name*/local/share/check_mk/checks/
* ./wato/check_parameters_egais_utm.py => /omd/sites/*site_name*/local/share/check_mk/web/plugins/wato/

To install the agent the the following to your Egais Utm server:
* ./agent/egais_utm.ps1 => MK_PLUGIN (usually C:\Program Files (x86)\check_mk\plugins\\)
* HtmlAgilityPack.dll => MK_ROOT (usually C:\Program Files (x86)\check_mk\\)
