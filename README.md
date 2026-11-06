# Warrior Tracker

Samostatná kopie addonu Hunter Range Bar pro WoW Forever. Hlavní pruh zachovává měření vzdálenosti a oranžové označení dosahu na blízko, ale nezobrazuje hunterovu mrtvou zónu. Zeleně blikne, když hra potvrdí dosah a použitelnost střelby vybavené zbraně; pokud tyto údaje neposkytne, střelbu nepotvrdí. Orientační hranice pruhu je 30 yd. V závislosti na zbrani a pravidlech klienta může mít střelba také minimální dosah.

Pod hlavním pruhem je červený ukazatel rage s aktuální hodnotou. Je stejně široký jako hlavní pruh, má 75 % jeho výšky a při změně velikosti nebo přesunutí se mu přizpůsobí.

Použité schopnosti přibývají do sloupce nad pravým koncem hlavního pruhu. Jejich vlastní cooldown se odpočítává; přes ikony je zároveň kruhový průběh globálního cooldownu (GCD). Vedle schopností vyžadujících rage se červený ukazatel plní podle aktuálního rage až po potřebné minimum, které je uvedeno číslem. Pokud je rage dost, ikona se zeleně zvýrazní nezávisle na GCD; při čitelné hodnotě rage navíc při přechodu blikne. Pro skrytou hodnotu se zkusí herní vykreslení pomocí procent a dříve přečteného maxima, bez bliknutí. Neznamená to, že skončil cooldown nebo že jsou splněny další podmínky použití. Pravým kliknutím ikonu odstraníš, `/wt clear` vyčistí celý sloupec. Pokud hra neposkytne cenu, maximum nebo potřebné API, nemusí být zvýraznění dostupné. Neznámou cenu značí `?`, a pokud není cooldown čitelný, použije se herní odpočet, je-li dostupný, jinak se zobrazí `?`.

Při pokusu o použití se schopnost zobrazí také jako pohyblivá ikona nad pravým koncem pruhu, vlevo od sloupce. Odtud jede doleva stálou rychlostí nezávislou na cooldownu a rage a na levém konci pruhu zmizí. Číslo nahoře na ikoně počítá uplynulé sekundy od 1 do 10. Samostatná ikona přejede dráhu za 10 sekund; nová ikona posune celou řadu doleva, pokud by se s ní předchozí překrývala, a tím může její cestu zkrátit. Zobrazují se pokusy hlášené hrou a úspěšná použití; hra nemusí hlásit každý stisk, například u schopnosti na cooldownu. Automatický útok a Auto Shot se nezobrazují.

Zbylé funkce jsou zatím zkopírovány z hunter addonu, včetně Hunter's Mark a tlačítka peta; pro warriora ještě nejsou upraveny.

Nastavení otevře `/wrt` nebo `/wt`. Další příkazy jsou `/wt lock`, `/wt unlock`, `/wt reset`, `/wt debug`, `/wt clear` a `/wt seznam`. Nastavení se ukládá odděleně od Hunter Range Bar.

Addon je ve složce `Interface\AddOns\WarriorTracker`. Oba addony lze nainstalovat vedle sebe; pokud jsou oba zapnuté, mohou se jejich panely překrývat. Pro správné zobrazení českého textu ponech ve složce soubor `Lato-Regular.ttf` a jeho licenci `Lato-OFL.txt`.
