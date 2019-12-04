# HPMC_Resign
 Usage of HPMC Resign:

./Resign -h or -?

Example:
./Resing **-v** *2.8* **-e** *api/hpmc* **-c** *dev-plt.plist* **-a** *yes* **-i** *"/path/of/the/ipa.ipa"*

-v Resigning HPMC 2.8/3.2 version -- **REQUIRED**

-e entitlements hpmc or api -- **REQUIRED**

-i ipaPath -- **REQUIRED**

-c config.plist replace? -- **OPTIONAL**

    usable configs:

      --THE SCRIPT WILL OUTPUT A LIST OF THE AVAILABLE .PLISTS--

-a resign Agents in the same loop? yes or no -- **OPTIONAL**

-o agents ONLY -- **OPTIONAL** *--> IF USED, USE NO OTHER AGRUMENTS THEN* -v -- **REQUIRED**
