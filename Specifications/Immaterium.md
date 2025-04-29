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

A counter that returns in seconds when fees can be billed next. 

- chapterToken 

Stores the token billed as fees. 

- verifyInst

A simple text entry that reads: 

"Find - Factory Address >> Read Functions >> Chapter Template - Verify"

- searchHearers 

Iterates over up to (1000) hearer entries and returns hearers who are eligible and due to pay fees, these are hearers whose ownCycle is below current chapterCycle and have approved enough of the chapter token and have a sufficient balance. 

- isHearer

Searches all hearer entries and returns full details if the address is a hearer, otherwise throws error. 

- lastCycleVolume 

Stores the total amount billed in the last cycle, updated by `billFee` calls. 

- chapterMapper 

Stores the address of the chapter mapper. 


**Functions**
- billFee 

Accepts hearer indexes param as "1, 2, 3..." for up to (100)  hearers, ignores hearers whose `ownCycle` is equal to current chapter cycle, iterates over up to (100) hearer addresses, attempts to charge hearers the `chapterFee` amount, skips if not approved or insufficient balance. Updates billed hearers' `ownCycle` to the latest `chapterCycle`. Accepts "ownKey" params for every hearer involved, formatted as "1234, 1234...", for the total number of hearers in the order which their indexes were passed. Hearers that weren't updated do not get their "ownKey". Avoids hearers whose status is inactive, clears inactive hearer entries and closes index gaps. Updates `oldKeys` for all affected hearers. Updates `lastCycleVolume`. All steps extracted into helper functions.  electOnly.  Can only be called if `nextFee` is zero, sets new `nextFee` time based on `feeInterval`. 


- hear 

Bills the caller the `chapterFee`, creates a new hearer entry with their address, sets status to active. Updates chapter mapper for `hearerChapters`, adding chapter address. 

- silence 

Sets a hearer's entry status to inactive, only callable by the hearerAddress for each entry. This effectively removes their subscription. Updates chapter mapper for `hearerChapters`, removing chapter address.    

- luminate 

Elect only, creates a new lumen entry with incremental index number and the current chapter cycle, accepts `dataEntry` param. 

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

- setCycleKey 

Determines the cycleKey string, increments the chapter cycle count, electOnly. 

- setChapterMapper

Determines the chapterMapper address, callable by anyone, cannot be reset. 



## **Immaterium Factory**
**Data** 
- LUX 

State variable, stores the LUX token address. 

- chapterLibrary

State Variable, stores the chapter library address. 

- validChapters

Mapping, stores the addresses of all chapters. 

- addressOfchapterMapper 

Stores the address of the chapter mapper. 

**Functions***

- setLux 

Determines the LUX token, ownerOnly. 

- setChapterLibrary 

Determines the library address where the chapter contract template is deployed. OwnerOnly. 

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



**Functions** 
- addChapter 

HearerOnly, adds a chapter address to a hearer's hearerChapters. Checks chapter validity on factory. 

- removeChapter

Same as "addChapter", but removes a chapter address. 

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

Mapping, stores the claimant address and timestamp since last claimReward call. 


**Functions** 
- mintRewards

Mint 25% of current supply to self. Resets swapCount to "0". Increases swapThreshold by a factor of "1", unless max threshold is reached. Can only be called if swapCount is > swapThreshold. Extract steps into helpers. Nonreentrant. 

- claimReward

Allows any holder to claim LUX from the contract balance, reward is an amount equal to 25% of the caller's LUX balance. Only callable if rewardEligibility has a timestamp older than one month. Sets timestamp to current time. All transfers/transferFrom to a new address add the receiver address to rewardEligibility with the current timestamp. 

- fees 

Each transfer or transferFrom takes a 1% fee which is held in the contract. 




# **Frontend**


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

// create a way to detect if someone is slugging a d subtract their... Nvm, Own Cycle must be lower than chapter cycle. 

// add swap interface for omf when possible

// Show bonus amount before claim fee button. 

Note : Possible exploit, someone can frontrun the billFee transaction and get their ownKey from the transaction.