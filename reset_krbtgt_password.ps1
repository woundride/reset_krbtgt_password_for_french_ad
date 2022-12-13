<#----------------------------------------------------------------------------------------------------
Ce script a pour but de vérifier que toutes les conditions sont requises avant de changer
le mot de passe du compte Krbtgt.
Il fonctionne uniquement sur un annuaire Active Directory en Français.
Attention, ce script est fourni sans aucune garantie et doit être utilisé avec une extrême
précaution afin d'éviter tout dysfonctionnement de l'annuaire Active Directory.
Son auteur ne pourra pas être tenu pour responsable de l'utilisation qui en est faite.
Afin de pouvoir modifier le mot de passe du compte Krbtgt, le script doit être exécuté avec
les privilèges nécessaires.
Autheur : Charles BLANC ROLIN
----------------------------------------------------------------------------------------------------#>
Write-Host ''
Write-Host '           __          ___.    __          __ '
Write-Host '          |  | ________\_ |___/  |_  _____/  |_' 
Write-Host '          |  |/ /\_  __ \ __ \   __\/ ___\   __\'
Write-Host '          |    <  |  | \/ \_\ \  | / /_/  >  |  '
Write-Host '          |__|_ \ |__|  |___  /__| \___  /|__|  '
Write-Host '               \/           \/    /_____/'
Write-Host ''
Write-Host 'RESET KRBTGT PASSWORD - FOR FRENCH ACTIVE DIRECTORY'
Write-Host '                                Charles BLANC ROLIN'
Write-Host '                       https://github.com/woundride'
Write-Host '                             https://www.apssis.com'
Write-Host '----------------------------------------------------'
Write-Host '            Licence Crative Commons CC BY-NC-SA 4.0'
Write-Host ' https://creativecommons.org/licenses/by-nc-sa/4.0/'
Write-Host '----------------------------------------------------'
Write-Host ''

$Date = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

Write-Host '   Date : ' -NoNewline; Write-Host -ForegroundColor Cyan $Date
Write-Host ''
Write-Host '----------------------------------------------------'
Write-Host ''

<#----------------------------------------------------------------------------------------------------
Import du module ActiveDirectory
----------------------------------------------------------------------------------------------------#>
Import-Module ActiveDirectory

<#----------------------------------------------------------------------------------------------------
Récupération des informations relatives au domaine
----------------------------------------------------------------------------------------------------#>

Write-Host 'Informations relatives au domaine :'
Write-Host ''

$TargetDomain = Get-AdDomain | Select Name,DNSRoot,NetBIOSName,DomainMode,PDCEmulator

Write-Host '   Nom NetBIOS : ' -NoNewline; Write-Host -ForegroundColor Cyan $TargetDomain.NetBIOSName
Write-Host '   Nom DNS : ' -NoNewline; Write-Host -ForegroundColor Cyan $TargetDomain.DNSRoot 
Write-Host '   PDC emulator : ' -NoNewline; Write-Host -ForegroundColor Cyan $TargetDomain.PDCEmulator
Write-Host '   Niveau du domaine : ' -NoNewline; Write-Host -ForegroundColor Cyan $TargetDomain.DomainMode
Write-Host ''
Write-Host '----------------------------------------------------'

<#----------------------------------------------------------------------------------------------------
Récupération des informations relatives au compte Krbtgt
----------------------------------------------------------------------------------------------------#>

Write-Host ''
Write-Host 'Informations relatives au compte Krbtgt :'
Write-Host ''

<#Modifications du format des dates et calcul de l'âge du mot de passe#>

$Date_cacl = Get-Date -Format 'yyyy-MM-dd'
$Krbtgt = Get-ADUser krbtgt -Properties PasswordLastSet -Server $TargetDomain.PDCEmulator
$Krbtgt_lastpwrd = $Krbtgt.PasswordLastSet
$Krbtgt_lastpwrd_cacl = [datetime]::parseexact($Krbtgt_lastpwrd, 'MM/dd/yyyy HH:mm:ss', [Globalization.CultureInfo]::CreateSpecificCulture('fr-FR')).ToString('yyyy-MM-dd')
$tdiff_krbtgt_pwrd = New-TimeSpan -Start $Krbtgt_lastpwrd_cacl -End $Date_cacl
$Age_krbtgt_pwrd = $tdiff_krbtgt_pwrd.Days

Write-Host '   Compte Krbtgt : ' -NoNewline; Write-Host -ForegroundColor Cyan $Krbtgt.DistinguishedName
If ($Age_krbtgt_pwrd -le '40') {
Write-Host '   Dernier changement de mot de passe pour le compte Krbtgt : ' -NoNewline; Write-Host -ForegroundColor Green $Krbtgt_lastpwrd
}
else
{
Write-Host '   Dernier changement de mot de passe pour le compte Krbtgt : ' -NoNewline; Write-Host -ForegroundColor Red $Krbtgt_lastpwrd
}
If ($Age_krbtgt_pwrd -le '40') {
Write-Host '   Âge du mot de passe du compte Krbtgt : ' -NoNewline; Write-Host -ForegroundColor Green $Age_krbtgt_pwrd ' jour(s)'
}
else
{
Write-Host '   Âge du mot de passe du compte Krbtgt : ' -NoNewline; Write-Host -ForegroundColor Red $Age_krbtgt_pwrd ' jours'
Write-Host -ForegroundColor Red '   Le mot de passe du compte Krbtgt doit être modifié !'
}
Write-Host ''
Write-Host '----------------------------------------------------'

<#----------------------------------------------------------------------------------------------------
Vérification des réplications pour l'ensemble des côntroleurs de domaine
----------------------------------------------------------------------------------------------------#>

Write-Host ''
Write-Host 'Vérification des réplications :'
Write-Host ''

$replication_result = '0'
$change_passwd = '0'

function repli-result

{

param ( [string]$Serv, [string]$partner, [string]$result,[string]$lastsuccess )

 

$ReplResult =New-Object PSObject

$ReplResult | Add-Member -Name Serveur -MemberType NoteProperty -Value '$serv'

$ReplResult | Add-Member -Name Partenaire -MemberType NoteProperty -Value '$partner'

$ReplResult | Add-Member -Name resultat -MemberType NoteProperty -Value '$result'

$ReplResult | Add-Member -Name DernierOK -MemberType NoteProperty -Value '$lastsuccess'

 

return $ReplResult

}

$dcs= Get-addomaincontroller -filter *

foreach ($dc in $dcs)

{

$b=Get-ADReplicationPartnerMetadata -target $dc.name
$date_repli = Get-ADReplicationPartnerMetadata -target $dc.name | Select LastReplicationSuccess

foreach ($a in $b)

{

<#Réplication HS#>

If ($($a.lastreplicationresult) -ne '0')

{

Write-Host '  ' $dc ' : ' -NoNewline; Write-Host -ForegroundColor Red 'Replication HS' -NoNewline; Write-Host ' | ' -ForegroundColor Cyan $date_repli.LastReplicationSuccess 
$replication_result = [int]$replication_result + 1

}
<#Réplication OK#>

If ($($a.lastreplicationresult) -eq '0')

{

<#Extraction des dates de réplication, transformation du format et comparaison avec dernière modification du mot de passe#>

$MM_replic, $dd_replic, $yyyy_replic = ($date_repli.LastReplicationSuccess -split '/')[0,1,2]
$yyyy_replic_calc = [datetime]::parseexact($yyyy_replic, 'yyyy HH:mm:ss', [Globalization.CultureInfo]::CreateSpecificCulture('fr-FR')).ToString('yyyy')
$date_repli_calc = "$yyyy_replic_calc-$MM_replic-$dd_replic"
$tdiff_synch_pass = New-TimeSpan -Start $Krbtgt_lastpwrd_cacl -End $date_repli_calc
$nb_jours_synch_passw = $tdiff_synch_pass.Days

<#Test nombre de jours entre réplication et changement de mot de passe (doit être supérieur à 2 pour que le changement de mot de passe soit fait#>

	If ($nb_jours_synch_passw -gt '2')
	{
	$change_passwd = [int]$change_passwd + 0
	}
	else
	{
	$change_passwd = [int]$change_passwd + 1
	}
	
Write-Host '  ' $dc ' : ' -NoNewline; Write-Host -ForegroundColor Green 'Replication OK' -NoNewline; Write-Host ' | ' -ForegroundColor Cyan $date_repli.LastReplicationSuccess

}

}
}

Write-Host ''
Write-Host '----------------------------------------------------'

<#----------------------------------------------------------------------------------------------------
Processus de changement de mot de passe pour le compte Krbtgt
----------------------------------------------------------------------------------------------------#>

Write-Host ''
Write-Host 'Processus de changement de mot de passe pour le compte Krbtgt :'
Write-Host ''

If ($replication_result -eq '0')

{

Write-Host  -ForegroundColor Green '   Le mécanisme de réplication est fonctionnel'
Write-Host ''

	If ($change_passwd -eq '0')
	
	{
	
	Write-Host -ForegroundColor Green "   Au moins 2 jours se sont écoulés"
	Write-Host -ForegroundColor Green "   entre l'ensemble des réplications"
	Write-Host -ForegroundColor Green "   et le dernier changement de mot de passe."
	Write-Host ''
	Write-Host ''                                                                           
	Write-Host -ForegroundColor Red "                                 .i;;;;i.                                  "
	Write-Host -ForegroundColor Red "                               iYcviii;vXY:                                "
	Write-Host -ForegroundColor Red "                             .YXi       .i1c.                              "
	Write-Host -ForegroundColor Red "                            .YC.     .    in7.                             "
	Write-Host -ForegroundColor Red "                           .vc.   ......   ;1c.                            "
	Write-Host -ForegroundColor Red "                           i7,   ..        .;1;                            "
	Write-Host -ForegroundColor Red "                          i7,   .. ...      .Y1i                           "
	Write-Host -ForegroundColor Red "                         ,7v     .6MMM@;     .YX,                          "
	Write-Host -ForegroundColor Red "                        .7;.   ..IMMMMMM1     :t7.                         "
	Write-Host -ForegroundColor Red "                       .;Y.     ;$MMMMMM9.     :tc.                        "
	Write-Host -ForegroundColor Red "                       vY.   .. .nMMM@MMU.      ;1v.                       "
	Write-Host -ForegroundColor Red "                      i7i   ...  .#MM@M@C. .....:71i                       "
	Write-Host -ForegroundColor Red "                     it:   ....   $MMM@9;.,i;;;i,;tti                      "
	Write-Host -ForegroundColor Red "                    :t7.  .....   0MMMWv.,iii:::,,;St.                     "
	Write-Host -ForegroundColor Red "                   .nC.   .....   IMMMQ..,::::::,.,czX.                    "
	Write-Host -ForegroundColor Red "                  .ct:   ....... .ZMMMI..,:::::::,,:76Y.                   "
	Write-Host -ForegroundColor Red "                  c2:   ......,i..Y$M@t..:::::::,,..inZY                   "
	Write-Host -ForegroundColor Red "                 vov   ......:ii..c$MBc..,,,,,,,,,,..iI9i                  "
	Write-Host -ForegroundColor Red "                i9Y   ......iii:..7@MA,..,,,,,,,,,....;AA:                 "
	Write-Host -ForegroundColor Red "               iIS.  ......:ii::..;@MI....,............;Ez.                "
	Write-Host -ForegroundColor Red "              .I9.  ......:i::::...8M1..................C0z.               "
	Write-Host -ForegroundColor Red "             .z9;  ......:i::::,.. .i:...................zWX.              "
	Write-Host -ForegroundColor Red "             vbv  ......,i::::,,.      ................. :AQY              "
	Write-Host -ForegroundColor Red "            c6Y.  .,...,::::,,..:t0@@QY. ................ :8bi             "
	Write-Host -ForegroundColor Red "           :6S. ..,,...,:::,,,..EMMMMMMI. ............... .;bZ,            "
	Write-Host -ForegroundColor Red "          :6o,  .,,,,..:::,,,..i#MMMMMM#v.................  YW2.           "
	Write-Host -ForegroundColor Red "         .n8i ..,,,,,,,::,,,,.. tMMMMM@C:.................. .1Wn           "
	Write-Host -ForegroundColor Red "         7Uc. .:::,,,,,::,,,,..   i1t;,..................... .UEi          "
	Write-Host -ForegroundColor Red "         7C...::::::::::::,,,,..        ....................  vSi.         "
	Write-Host -ForegroundColor Red "         ;1;...,,::::::,.........       ..................    Yz:          "
	Write-Host -ForegroundColor Red "          v97,.........                                     .voC.          "
	Write-Host -ForegroundColor Red "           izAotX7777777777777777777777777777777777777777Y7n92:            "
	Write-Host -ForegroundColor Red "             .;CoIIIIIUAA666666699999ZZZZZZZZZZZZZZZZZZZZ6ov.              "
	Write-Host ''
	Write-Host ''
	Write-Host '   Attention le mot de passe va être automatiquement modifié dans 60 secondes'
	Write-Host '   Pour annuler : Ctrl+c'
	Start-Sleep -s 60
	
	<#Après 60 secondes le mot de passe est modifié#>
	
	net user krbtgt XaEkrei1X37HjAvTwPqZh60
	
	<#Le mot de passe spécifié ici sera automatiquement remplacé par un mot de passe aléatoire#>
	
	}
	
	else
	
	{
	
	Write-Host -ForegroundColor Red "   Le mot de passe ne peut pas être modifié."
	Write-Host -ForegroundColor Red "   L'ensemble des réplications doivent dépasser"
	Write-Host -ForegroundColor Red "   de 2 jours, la date du dernier changement de mot de passe."
	
	}
	
}

else

{

Write-Host -ForegroundColor Red '   Dysfonctionnement du mécanisme de réplication'
Write-Host ''
Write-Host -ForegroundColor Red '   Le mot de passe ne peut pas être modifié'

}
