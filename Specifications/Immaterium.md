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


- searchHearers 

Iterates over up to (1000) hearer entries and returns hearers who are eligible and due to pay fees, these are hearers whose ownCycle is below current chapterCycle and have approved enough of the chapter token and have a sufficient balance. 

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


**Functions**


- billFee 

Requires hearer cell index, attempts to bill all active hearers in the cell, avoids hearers whose status is inactive, clears inactive hearer entries and closes index gaps.  Updates `lastCycleVolume` based on total billed. All steps extracted into helper functions.  electOnly.  Can only be called if `nextFee` is due or zero, sets new `nextFee` time based on `feeInterval`. If a hearer cannot be billed due to insufficient balance or approval then this skips the hearer. 


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

- nextCycleKey 

Determines the cycleKey string, sets ownKey for active hearers whose ownCycle is below current chapter cycle, accepts params for ownKeys as "(string), (string)", targets hearers by "cell", requires cell index, avoids setting ownKey to inactive hearers, increments the chapter cycle count, electOnly. 

- setChapterMapper

Determines the chapterMapper address, callable by anyone, cannot be reset. 

setChapterName 

ElectOnly, determines the chapter name string. Calls `addName` at the chapterMapper with the chapter's name. 

setChapterImage 

ElectOnly, determines the chapter image string. 



## **Immaterium Factory**
**Data** 
- LUX 

State variable, stores the LUX token address. 

- chapterlogic

State Variable, stores the chapter logic address. 

- validChapters

Mapping, stores the addresses of all chapters. 

- addressOfchapterMapper 

Stores the address of the chapter mapper. 

**Functions***

- setLux 

Determines the LUX token, ownerOnly. 

- setChapterlogic 

Determines the logic address where the chapter contract template is deployed. OwnerOnly. 

- deployChapter 

Creates a new chapter using the chapter contract template, passing "salt" for deterministic address generation. Sets elect - feeInterval - chapterFee - chapterMapper and chapterToken based on caller input. Stores the chapter address in `validChapters`. Extract all steps into helper functions. 

- setAddressOfChapterMapper 

Sets the address for addressOfChapterMapper, callable by anyone, cannot be reset. 

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

Iterates through chapter names and returns all results that are either partial or whole matches. Caps at (1000) results. 

- queryExactName 

Iterates through chapter names and returns an exact name + address, if any. Does not cap iterations. 

- setFactoryAddress 

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
All dependencies are local, no CDNs, uses alpine.js for state management, bootstrap-5 for CSS and Vanilla Javascript for complex logic. 
To be deployed to IPFS via 4everland. 

## **Section 1** 
### **Connect Wallet (Button)**
Presents the wallet connection pop-up modal. Positioned top right of the page. 
Button displays text "Connect Wallet", in current button styles. 

### **Network Select (Button)**
Presents browser pop-up "connect wallet first" if wallet is not connected. 
If connected checks if user wallet is using "correct network", if not check if user wallet has "correct network", if not push request to add network. 
Stores if network is known but not connected, then push request to change network. 
Button displays "🌐" if user network is not correct, or "sonicLogo.png" from "./assets/" if network is not correct. 
Buttoj is displayed top left aligned left of "Connect Wallet" button with a few pixels of space. 


### **Immaterium Logo**
Displayed top left, is somewhat small but still visible. 
Is "./assets/immateriumLogo.png". 

## **Section 2**
### **Landing Panel**
A penel containing three elements : 

**Landing Blurb**
Text that reads; "Welcome! Immaterium 

## **Section 3**

## **Background**

### **Wallet Connection Pop-up modal**
Presets a pop-up that appears centered above everything else, can be clicked or tapped out of to close. 

- Browser Wallet 
Uses window.ethereum 

// Implement basic features, exclude OMF and LUX, exclude chainMail, comment to-do

// flow should be all posts are public until first hearer, then elect must set keys before billing, 

Frontend: Gets links from lumen string, determines what kind of data it is, avoids malicious Javascript execution. Support images - PDFs and markdown at first, then later music - videos etc.

Enable md auto formatting for lumening and reading, 

Each lumen is encrypted using a "key", the key is generated at the start of each month and is used to encrypt every lumen for the month. 


lumen are encrypted

Frontend sorts hearers into (100) unit batches.

MaxIteration is 100

Calculate potential "haul" for each interval cycle when billFee is callable, use "claim" button. Have pop-up to indicate if

Calculate hearers who can afford to pay fee at interval, calculate how much they've approved (shoukd be bigNumber but check). Process their ownKey and prepare billFee params. Check current cycle against hearer details to determine who has gotten their key. Avoid sending key at all to hearers who can't afford fee or don't have enough approved.

Create a text encoder in frontend that takes an image and outputs an encrypted text file using the cycle key. Adds a tag to the text file that when read will decrypt the image using the cycle key. 

Cycle key is randomly generated 24 character alphanumeric string, is encrypted using the elect's private key and stored under `cycleKey`. Key is retrieved during each lumen. 

Feeinterval is in seconds, calculate options for intervals in days, weeks, months or years. 

Before billing fees, set cycle key, use cycle key for every lumination.  

//  frontend distinguishes private vs public chapters by "0" as ownKey and cycleKey. Have private/public indicator 

// create a way to detect if someone is slugging a d subtract their... Nvm, Own Cycle must be lower than chapter cycle. 

// add swap interface for omf when possible

// query strings in url

// Show bonus amount before claim fee button. 

// "you have no (token)" during hear, "get (token)" button presents pop-up that reads "coming soon!", if LUX push transaction to 

// can't set cycle key until after first hearer and billing, all posts public till then

// landing page has link to "faucet" "All transactions cost gas, get some at [link]"

// warning about chapter name length, will not be mapped. 

Note : Possible exploit, someone can frontrun the billFee transaction and get their ownKey from the transaction.  
