# **Premise**
A decentralized subscription service using asymmetric encryption.

# **General**
The system is made up of (4) contracts: the `ImmateriumFactory` - `ImmateriumChapter` - `chapterMapper`  and `Luminary Token`. 

## **Immaterium Chapter**
**Data** 
- hearers 

struct hearer 

hearerAddress 
ownKey
ownCycle
status

- elect

Stores the address of the `elect`, certain functions are restricted to `electOnly`. All fees are sent directly to the elect. 

- feeInterval

Stores the interval in seconds at which `billFees` can be called. 

- chapterCycle

Stores the current `feeInterval` height, indicating how many times fees have been collected. 

- lumen 

struct lumen 

dataEntry
cycle
index

Stores each lumen entry with index number and `dataEntry` string. 

- oldKeys 

mapping oldKeys 

key 
hearerAddress 
cycle

Stores all prior hearer ownKeys, is updated each time fee is billed. 

- cycleKey 

array string 

- chapterFee 

State variable, determines the amount to charge hearers at the fee interval. 

- nextFee 

A timestamp of when fees can be billed again. 

- chapterToken 

Stores the token billed as fees. 

- cellHeight 

Stores the total number of hearer cells. 


- isHearer

Searches all hearer entries and returns full details if the address is a hearer, otherwise throws error. 

- lastCycleVolume 

Stores the total amount billed in the last cycle, updated by `billFee` calls. 

- chapterMapper 

Stores the address of the chapter mapper. 

- chapterImage 

Stores the chapter image string.

- chapterName 

Stores the chapter name string. 

- historicalKeys

Maps old hearer cycles to old keys. 

- pendingCycle 

Is the unofficial latest cycle if cell is billed but not the highest cell. 

- 


**Functions**
- hear 

Bills the caller the `chapterFee`, creates a new hearer entry with their address, sets status to active. Updates chapter mapper for `hearerChapters`, adding chapter address. 

- silence 

Sets a hearer's entry status to inactive, only callable by the hearerAddress for each entry. This effectively removes their subscription. Updates chapter mapper for `hearerChapters`, removing chapter address.    

- luminate 

Elect only, creates a new lumen entry with incremental index number and the current chapter cycle, accepts `dataEntry` param. 

- nextFeeInSeconds 

Gets `nextFee` and current block timestamp, calculates time till next fee, returns in seconds - minutes and hours. 

- getCellHearerCount 

All hearers are sorted in 100 index cells for batch operations. This function returns the number of hearers in a cell. 

- getActiveHearersCount  

Returns the total number of active hearers. 

- getCellAddresses 

Returns all addresses in a cell in the order of their indexes.  

- getLaggards 

Returns all addresses whose ownCycle is lower than chapterCycle. 

- searchHearers 

Iterates over all hearer entries and returns hearers who are eligible and due to pay fees, these are hearers whose ownCycle is below current chapterCycle and have approved enough of the chapter token and have a sufficient balance.  

- reElect 

electOnly, changes the elect address. 

- changeFee

Calls billFee, then changes the fee state variable. Can only be called if `nextFee` is zero. electOnly. 

- setElect 

Used to set elect address. Callable by anyone, cannot be reset, can only be changed with "reElect". 

- setFeeInterval 

Determines the fee interval, callable by anyone, cannot be reset. 

- setChapterFee 

Determines the chapter fee, callable by anyone, cannot be reset. 

- setChapterToken 

Determines the chapter token, callable by anyone, cannot be reset. 

- nextCycleBill

Determines the cycleKey string, sets ownKey for active hearers whose ownCycle is below current chapter cycle, accepts params for ownKeys as "(string), (string)", targets hearers by "cell", requires cell index, avoids setting ownKey to inactive hearers, increments the chapter cycle count, electOnly. Skips ownKeys if no hearers exist or none exist up to ownKeys provided. Sets ownKey if provided keys reach cycleKey limit. 
Only updates nextFee and chapterCycle if the highest cell is billed, does not bill hearers whose ownCycle is equal to or greater than pendingCycle or chapterCycle. 


Fee billing as part of nextCycleBill: 
Requires hearer cell index, attempts to bill all active hearers in the cell, avoids hearers whose status is inactive, marks addresses that could not be billed as inactive, clears inactive hearer entries and closes index gaps.  Updates `lastCycleVolume` and `totalVolume` based on total billed. All steps extracted into helper functions.  electOnly.  Can only be called if `nextFee` is due or zero, sets new `nextFee` time based on `feeInterval`. If a hearer cannot be billed due to insufficient balance or approval then this skips the hearer. Does not set nextFee if there are no hearers. 

- billAndSet 

Sets ownKeys for a hearer, only applicable to hearers whose ownCycle is below current chapterCycle. Accepts comma delimited indexes for cycles and another param for keys. Bills the hearer and sets ownCycle to current chapterCycle. 

- setChapterMapper

Determines the chapterMapper address, callable by anyone, cannot be reset. 

- setChapterName 

ElectOnly, determines the chapter name string. Calls `addName` at the chapterMapper with the chapter's name. 

- setChapterImage 

ElectOnly, determines the chapter image string. 



## **Immaterium Factory**
**Data** 
- LUX 

State variable, stores the LUX token address. 

- chapterlogic

State Variable, stores the chapter logic address. 

- validChapters

Mapping, stores the addresses of all chapters. 

- chapterMapper 

Stores the address of the chapter mapper. 

**Functions***

- setLux 

Determines the LUX token, ownerOnly. 

- setChapterlogic 

Determines the logic address where the chapter contract template is deployed. OwnerOnly, can be reset. 

- deployChapter 

Creates a new chapter using the chapter contract template, passing "salt" for deterministic address generation. Sets elect - feeInterval - chapterFee - chapterMapper and chapterToken based on caller input. Stores the chapter address in `validChapters`. Extract all steps into helper functions. 

- chapterMapper 

Sets the address for chapterMapper, ownerOnly, can be reset. 

## **Chapter Mapper** 
**Data** 
- HearerChapters 

Mapping, stores hearer address and subscribed chapters. 

- factoryAddress 

Stores the factory address 

- chapterNames 

Struct, stores chapter names with their address via an array.   



**Functions** 
- addChapter 

HearerOnly, adds a chapter address to a hearer's hearerChapters. Checks chapter validity on factory. 

- removeChapter

Same as "addChapter", but removes a chapter address. 

- addName 

Adds a passed name and address to the `chapterNames` array. Verifies that the call originates from a valid chapter. Same name or address cannot be added twice. 

- queryPartialName 

Iterates through chapter names and returns all results that are either partial or whole matches. 

- setFactoryAddress (ownerOnly)

Determines the factory address. 



## **Luminary Token** 
An ERC-20 reward token. 

**Data** 
- swapCount 

Each transfer or transferFrom above 0.01% of supply is counted. 

- swapThreshold 

Stores the latest swap threshold. Max threshold is 2500. 

- rewardEligibility 

Mapping, stores the claimant address and timestamp since last claimReward call. Is set initially for recipients by transfers and transferFroms. 

- supply 

Initial supply is 10. 

**Functions** 
- mintRewards

Mint 25% of current supply to self. Resets swapCount to "0". Increases swapThreshold by a factor of "1", unless max threshold is reached. Can only be called if swapCount is > swapThreshold. Extract steps into helpers. Nonreentrant. 

- claimReward

Allows any holder to claim LUX from the contract balance, reward is an amount equal to 25% of the caller's LUX balance. Only callable if rewardEligibility has a timestamp older than one month. Sets timestamp to current time. All transfers/transferFrom to a new address add the receiver address to rewardEligibility with the current timestamp. Nonreentrant. 

- fees 

Each transfer or transferFrom takes a 0.05% fee which is held in the contract. 



# **Frontend**
All dependencies are local, no CDNs, uses alpine.js for state management, bootstrap-5 for CSS and Vanilla Javascript for complex logic. Avoid heavy images (>100kb), avoid animations and unnecessary sub-routines. 
Use function connectors/selectors found on the contract pages on sonicscan to push transactions or query data, avoid encoding ABIs to push transactions. 
Use query strings for sharing URLs with specific modals and data open, such as chapter addresses or feeds. 
If using template, change colors to variations of peach. 

## **Section 1** 
### **Connect Wallet (Button)**
Presents the wallet connection pop-up modal. Positioned top right of the page. 
Button displays text "Connect Wallet", in current button styles. 

### **Network Select (Button)**
Presents browser pop-up "connect wallet first" if wallet is not connected. 
If connected checks if user wallet is using "correct network", if not check if user wallet has "correct network" saved, if not push request to add network. 
Stores if network is known but not connected, then push request to change network. 
Button displays "🌐" if user network is not correct, or "sonicLogo.png" from "./assets/" if network is not correct. 
dApp will use whatever network is connected even if "incorrect", but an incorrect network will not interact with the right contracts. [See note #1]
Button is displayed top left aligned left of "Connect Wallet" button with a few pixels of space. 

"Correct" network settings are: 

Network Name: Sonic Blaze Testnet
RPC URL: https://rpc.blaze.soniclabs.com
Explorer: https://testnet.sonicscan.org
Chain ID: 57054
Currency Symbol: S

Until mainnet.


### **Immaterium Logo**
Displayed upmost left, is somewhat small but still visible. 
Is "./assets/immateriumLogo.png". Can be clicked on to return to the landing blurb. 

## **Section 2**
### **Landing Panel**
A penel containing these elements : 

**Landing Blurb**
Text that reads; "Welcome! Immaterium is a subscription and social media system using asymmetric encryption, all media is user managed with no central server. Try it!"

**Search Button**
Presents a search pop-up modal. 
Appears bottom left of the panel in general button style. 

**Create Button** 
Presents a chapter creation modal. Appears bottom right of the panel in general button style. 

**User Feed Button**
Is a circular button with a "📜" symbol at the top right of the panel, presents the user feed modal. 

**Get Gas** 
Is a text link to : "https://testnet.soniclabs.com/account". Is not in general button style, is small and underlined. 

---

Note that section 2 can dynamically expand based on the displayed modals' contents. 

## **Section 3**
**Links**
Text links to

 "Github" : "https://github.com/Peng-Protocol/Appmaterium", 

"Factory" : "https://testnet.sonicscan.org/address/0xAbd617983DCE1571D71cCC0F6C167cd72E8b9be7#readContract" 

"Twitter (X)" : 
"https://x.com/Dexhune" 

**Light/Dark Mode Toggle**
Toggles light or dark mode panels and background, uses system default when app is launched, overides default if clicked. 


## **Background**
A dim gray and dark gray or light gray and dim gray gray circuit board pattern. 

### **Wallet Connection Pop-up modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

**Browser Wallet Button** 
A button that reads "Browser Wallet", triggers wallet connection with window.ethereum. Stores the wallet connected state and address. Truncated Address replaces "Wallet Connect" button. Truncated address can be clicked on to disconnect. 

Is overroded by template wallet connect. 

**QR Code** 
Presents QR code modal. 

### **Search Pop-up modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

Uses "queryPartialName (0x01f2e8dc)" on chapterMapper contract, displays returned Chapter addresses with their names as cards. Chapter cards can be clicked on to open Chapter Modal with the returned address.


### **Chapter Creation modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

Has fields for "Fee Interval" - "Fee Amount" - "Fee Token". Sets connected wallet as "Elect", parses "Fee Amount" to IERC20 decimals at Fee Token address, e.g 18 decimals with a frontend input of "2" is 2e18 or "0.01" is "1e16". Default chapter token is "LUX (0xd174d584)" on ImmateriumFactory, Field is titled "LUX" if unchanged, accepts ERC20  token addresses. 

The "Fee Interval" is parsed as weeks and months, the contract field takes interval in seconds, example; 604800 seconds is 1 week. 

Has a "Get LUX" button that opens the "Light Source Modal" over the current modal. 

Once a chapter is created, frontend opens the chapter modal with the new chapter contract addresses. 

Frontend presents a temporary (10 seconds) popup that reads "You need to initialize your chapter", pushes a transaction for nextCycleBill, there are no hearers, thus this sets the first cycleKey, hearer ownkeys and cell index is "0". Produces a pure cycleKey encrypted with the Elects's public key, this is used as the passed cycleKey. 

**Help Button**
Presents additional pop-up that reads: "Use this menu to create new Immaterium Chapters, you can set any token you want for your hearers (subscribers), to pay you in, the default token is "LUX" a gold pegged reward token where you can earn 25% bonuses every month". 

Button appears at the bottom left of the modal in a circle with "?". 

### **Light Source Modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

Has a disclaimer in small text that reads "You may receive 0.01 LUX per address, there is (balance) in the Light Source". Uses IERC20 balanceOf at the Light Source contract address. 

Has a "Get" button which pushes "claim (0x1e83409a)" on the light source contract using the LUX token address as passed parameter. 


### **QR Code Modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

Presents a QR code of the wallet connection URI. Has an "address" field, sets address into URI if provided. Has "copyURI" button. Allows wallet comnect by URI or QR for wallets that support it. 

Is overrided by template QR functionality. 


### **Chapter modal**
Presents Chapter Details for a specific Chapter Address. 

**Chapter Image**
Upper left panel. Uses the link in "chapterImage (0x17f4e7e1)" on the immaterium chapter. If clicked on by the Elect - "elect (0x7bd955f3)" - Presents Chapter Profile Modal. If clicked on by non-elect, presents the chapterImage. 


**Chapter Name**
Upper left panel  Displays the string in "chapterName (0x06a76993)" on the immaterium chapter. 

**Pending Fees** 
Top left panel. Fetches nextFee timestamp using "nextFee (0xa0fb5d94)" at the chapter address, parses the timestamp into yy/mm/dd/hh/m/s. Fetches "getActiveHearersCount (0xfbd7c9d8)" and calculates : "hearer count * chapterFee" if nextFee is due, presents result as "(amount) (token ticker symbol)". 


**Chapter Hearer Count**
Top left panel. Queries "getActiveHearersCount (0xfbd7c9d8)" on the immaterium chapter, uses "chapterFee (0x84f0f15a)" to calculate cycle profit as "hearer count * chapter fee", returns as "(amount) (ticker symbol) per (fee interval parsed)". Ticker symbol is gotten using IERC20 "symbol" at token address. 

**New Post Button**
Top right panel, is a "💫" in a circle, opens "Lumen Creation Modal", button is only visible to the elect. 

**Subscribe Button**
Top right panel. Is a "↖️" in a circle, if clicked; presents a small pop-up with a "cyclesToHear" field starting at "1". The number in "cyclesToHear" is used as ; "cyclesToHear * chapterFee", result becomes the amount approved, the amount is used when "enter/return" is hit while in the field, this pushes a transaction for "Approve" at the LUX token contract for the target chapter, presents temporary pop-up that says "Approval and Subscription are (2) transactions". Proceeds to push transaction for "hear (0x80b448fe)". Once transaction is complete, change "Cs1".  

If the user's balance is insufficient before "hear" is pushed, then present 30 seconds pop-up that reads; "You have no (token)" during hear, "get (token)", if "token" is LUX then allow the (token) text in the pop-up to be clicked to open "Light Source" modal. Pop-up can be prompted repeatedly by hitting enter/return in the cyclesToHear field. 


**UnSubscribe Button**
Top right panel. Is a "↘️" in a circle, pushes a transaction for "silence (0xfa537f74)". Retains ownKeys cached and existing posts remain visible. Unsubscribe button is only visible if subscribed, replaces subscribe button.

**Subscription Status** 
Is "🫂" symbol in a circle, only appears if the connected address is subscribed or is elect, otherwise presents a "😶‍🌫️" symbol. 

**Help Button**
Top right panel. Is a "❔" in a circle, displays a help pop-up modal that shows all buttons with symbols and a short explanation of what they do. 

**Chapter Post Modal** 
Displayed inside the Chapter Modal, fetches "lumenHeight (0xf4d87851)" on the chapter contract, queries "lumens (0x2a642480)", passing the lumen height (minus 1, indexing starts from zero but counts start from 1). Returns "dataEntry" string in the post body, starting from the highest index downwards. 

Lumens are (supposed to be) encrypted. If the address is an active hearer then query  "historicalKeys (0xaec25182)", query using the connected wallet address and lumen's cycle number (starts counting from 1) as passed params. 

If cycleKey or ownKey is "0" this indicates unencrypted posts and can be viewed normally. 

If hearer ownCycle in "isHearer (0x88302aac)" isn't up to target lumen's cycle then return "Error : Key not updated". 

OwnKeys are encrypted asymetrically using the hearer's public key, push operation in wallet to decrypt ownKey using private key. This will only occur if a post is encrypted and the hearer has an ownKey for the cycle, will only trigger if post is clicked or tapped on. Use decrypted key to decrypt posts for a given cycle. Cache keys in browser for future use. 

Once key for a cycle is acquired then automatically decrypt all posts of that cycle. 

All encrypted posts where the ownKey is available but not yet decrypted will display "Click to begin decryption". 

Whereas encrypted posts where the ownKey is not available will display "Key not available, ensure you have sufficient balance or approval to pay fees - Contact your chapter's Elect for assistance". 

Cs1 : once a user subscribes but Elect has not set their keys, display "Elect confirmation pending, please contact Elect if this persists" on encrypted posts instead of prior message. 

Once a post is decrypted, if the post contains plain text then this is rendered in the post body, but if it contains file links they are either displayed in the post body if images, or embedded with large "📑" symbols with truncated file names that can be clicked or tapped on to download the contents. Files are sorted in the order they are pasted in the dataEntry and render around plain text. 

If there are no posts, display "Nobody here but us chickens!".

Displays up to 200 characters and up to (3) files as preview unless post modal is clicked/tapped, then hides all other posts and presents selected post in full. Has "↩️" at the top left to return to post previews. 

Supports markdown with "🪜" button at the top left that fetches and returns all headings - titles and subtitles in order, this is presented in a "postMap" pop-up where each part can be clicked on to go to its position on the post render. 

Display timestamp at thr bottom of the post in small gray text as;  "DD/MMM/YYYY" "HH/MM" or "HH Ago" if within 24 hours of current time. 

### **User Feed Modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

Uses "hearerChapters (0x4efc3d12)" with connected "address" and index numbers from "0". Gets the returned chapter addresses and queries (10) of their latest lumens in the same manner as the Chapter Post Modal. Sorts lumens by date/time. At the end of the feed will be a "More" button, this queries and presents the next (100) Lumens on subscribed chapters. 

**Subscriptions** 
A "⚙️" symbol button at the top right of the modal, replaces the feed with a list of chapters the address is subscribed to, uses "chapterName (0x06a76993)" on each chapter to display chapter names, and "chapterFee (0x84f0f15a)" scaled based on tbe token's decimals. Each chapter card has a "Cancel" button that pushes "silence (0xfa537f74)" at the target chapter address. 

In each chapter card, displays "Cycles Left" as "allowance / chapterFee", displayed as "(number) Cycles left". Has "Extend" and "Cut" buttons that change allowance for the chapter, presenting a pop-up  similar to "cyclesToHear" that adjusts the IERC20 token allowance based on the provided number. 

**Hearer Notifications**
Fees for all chapters are cached in the frontend and queried once as part of each launch process, if fees have changed then present 30 seconds notification pop-up highlighting the name of the chapter - fee change and existing approval. 

### **Encryption Functionality**
Posts (lumens) are first encrypted using a "pure" cycleKey. The frontend generates a pureCycleKey as a random 6 symbol alphanumeric string. The pureCycleKey is then encrypted using the Elect's public key, this output is used as the "key" in the chapter contract during "nextCycleBill (0x32244167)" and becomes "cycleKey (0xa4f91194)" for the latest cycle. 

For consistency, the cycleKey is either cached or fetched and decrypted using the Elect's private key via their wallet, if key is forgotten or corrupted then it is fetched and decrypted again. 

Each hearer's ownKey is the pureCycleKey but encrypted using the hearer's public key, hearer public key is gotten using "getCellHearers (0x56551822)". 

When nextCycleBill is called, the passed "ownKeys" are pureCycleKeys encrypted individually for valid hearers. 

Needs to be compatible with Metamask encrypt/decrypt standard. 

Updating ownKeys happens incrementally in multiple transactions calling nextCycleBill, starting from the lowest cell "0", cache last cell updated. Use "getCellHeight (0x2c5b8b7b)" to determine which cell is the final (Note : cellHeight starts counting from "1" but getCellHearers takes index numbers starting from "0").



### **Chapter Profile Modal**
A pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

Displays menu for managing chapter details,  can only be viewed by Elect address. 

**Chapter Name**
Displays the name string of the chapter, is a field, can be editted, has "💾" button that becomes clickable/tappable if changes are made, "💾" pushes a transaction for "addChapterName (0xefa12995)" on the immaterium chapter. 
Has warning if chapterName is longer than 100 characters; "Too long, can be used but will not be mapped". 

**Chapter Image**
Displays the image and link string of the chapter, is a field, can be editted, has "💾" button that becomes clickable/tappable if changes are made, "💾" pushes a transaction for "addChapterImage (0x0691c1bb)" on the immaterium chapter. 
Has a "⬆️" button that presents the Imgur modal to appear above the current modal, uses image link from uploaded image in Imgur modal. 

**Pending Fees**
Queries nextFee, if elapsed not then return "0" as pending fees, if elapsed then: queries "searchHearers (0x448e0c9c)" and gets the number of returned addresses, calculates : "number of hearers * chapterFee", displays the pending fee amount as ; "(amount) (ticker symbol)". 

Has "Claim" button that becomes clickable/tappable if nextFee is elapsed. Queries getCellHearers for the first cell or previous cell if billing is in progress, caches last billed cell [checks for discrepancies between "chapterCycle (0x6f617672)" and "pendingCycle (0xa155285f)", to indicate if biling has already started, if already started then try to fetch the last call for nextCycleBill to the chapter and retrieve the last used cell - in the event cache is expunged].  Encrypts pure cycle key for each individual hearer, passes cell index and comma delimited encrypted ownKeys, e.g "1234abcd,5678efgh,9101112ijkl...".  Pushes transaction for nextCycleBill. 

**Next Fee Counter**
Is fornatted as "yy/mm/ww/dd/hh/m/s", displays next fee time. 

**Rewards**
Queries "rewardEligibility (0xfcec6769)" and "balanceOf (0x70a08231)" using the connected address. If "rewardEligibility + 2,592,000 < current timestamp", then calculate ; "user balance / 100 * 25", queries "balanceOf (0x70a08231)" at the LUX contract address, if contract balance is greater than expected user rewards then present user reward value as "(rewardAmount) (LUX)". 

Has "Claim" button which pushes "claimReward (0xb88a802f)".

Has additional counter that queries "swapCount (0x2eff0d9e)" and "swapThreshold (0x0445b667)", calculating ; "swapThreshold - swapCount", if result is zero then this counter becomes a "🚀" button that pushes "mintRewards (0x234cb051)" if clicked/tapped. 

**Laggards** 
A counter that queries "getLaggards (0xdee324c5)", caches addresses but only displays the number of addresses. Has a "🫵" button which is only clickable/tappable of there are laggards, pushes "billAndSet (0x793d6bbe)" using the laggard's address, fetches all cycleKeys "cycleKey (0xa4f91194)"  then decrypts them using the Elect's (own) private key, then encrypts the pure keys for the laggard's cycleIndexes and ownKeys comma delimited. 

**Notifications** 
Displayed as a red dot at the top right of the chapter image. Is present if there are laggards or rewards or pending fees. Presents temporary pop-up when app is open and new notifications occur, pop-up indicates event, scans for new events every minute. 

**Elect**
Displays the elect address in a field, field can be edited to set new elect using "💾" button next to the field. Ensures new address is valid, presents pop-up with warning "You are about to give away control of your chapter" with "ok" and "cancel" options. Pushes transaction for "reElect (0xfc7be2b2)". 

### **Imgur Modal**
Has oAuth integration where user can input their Imgur login details or create new account once account is created or logged in, save session token for future use. 
Allows user to upload new files and fetch direct links to the files ending with the file name extension. 
Has a simple galley of user files based on Imgur's interface, allows uploading multiple files concurrently and fetching their file links. 

### **Lumen Creation Modal**
Has field for dataEntry, has "⬆️" button that presents Imgur modal, uses retrieved links of uploaded file(s) in data entry for "luminate (0xead08026)". Has option for "public" or "private" which is a single button toggle, default ia private and encrypts the post with the pure cycleKey, if not then no encryption happens and ownKeys are set to "0" . Pushes luminate when "⏫" button is  licked. dataEntry field accepts text, links are pasted into the field. Displays post modal for the new lumen once created. 

### **Testnet Addresses**
- **Factory** 

https://testnet.sonicscan.org/address/0xAbd617983DCE1571D71cCC0F6C167cd72E8b9be7#readContract

**Factory** : 0xAbd617983DCE1571D71cCC0F6C167cd72E8b9be7 

**LUX** : 0x9749156E590d0a8689Bc30F108773D7509D48A84

**ChapterMapper** : 0x6E36C9b901fcc6bA468AccA471C805D67e6AAfb8

**ChapterLogic** : 0x16631154248F6557aA1278A0B65cB56EEc6b3771

Most addresses can be found on the factory with exception of the immaterium chapter template. 

- **Chapter Template**

https://testnet.sonicscan.org/address/0x711491cfb400b3b7bfc42cedbb821f637195029e#readContract

Subject to change, sample ImmateriumChapter deployed from factory. 

- **Light Source**

https://testnet.sonicscan.org/address/0x0a8a210aff1171da29d151a0bb6af8ef2360d170#code

**LightSource Address** : 0x0a8a210aff1171da29d151a0bb6af8ef2360d170 


## **Notes**
1. In the event we have renounced the domain name and there is no way to update the frontend, if a significant blockchain network change occurs, the current "correct network" will be incorrect.

2. To Elix : remember to change links - get gas and correct network when moving to mainnet.

3. To Elix :  in mobile version perform automatic fee change notifications via chainMail. Also automatically billAndSet new hearers.

4. To Elix : in mobile version add notifications for updating allowance.

5. To Elix : in the future we could add USD price display for hearer count if LUX is chapterToken. 