# BlockchainXItalo
<p align="center"><img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Ethereum.png" width="80"> <img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/For.png" width="40"> <img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Italo.png" width="180"/></p>

This project is meant to help Italo improve their compensation process by making use of blockchain technologies, especially smart contracts.

## 1. The Webservice

<img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Python.png" width="20"> The webservice has been written using Python 3.9 as a language and the FastAPI package.

See the [webservice code](https://github.com/RebSolcia/BlockchainXItalo/blob/main/code/webservice.py).


## 2. The Smart Contracts

<img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Remix.png" width="20"> The smart contracts have been written in Solidity and compiled using Remix, a web IDE.

<img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Kovan.png" width="20"> The contract has been deployed using the Kovan testnet, and its Test ETH and Test LINK.

<img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Metamask.png" width="20"> The Injected Web3 Provider used is Metamask.

<img src="https://github.com/RebSolcia/BlockchainXItalo/blob/main/README_pics/Chainlink.png" width="20"> It has been possible to make API calls from the contract by using Chainlink, the most famous oracle provider.

### 2.1 The Library Utils smart contract
The Library Utils smart contract is a Solidity library we created on purpose, to help parsing one data type to another (see the [Library Utils contract](https://github.com/RebSolcia/BlockchainXItalo/blob/main/code/LibraryUtils.sol)).

The most crucial functions contained inside of the Converter library belonging to the file LibraryUtils.sol are:
* split(string, delimiter), returning an array of the elements of the splitted string
* bytes32ToString(bytes32)
* stringToBytes32(string)
* StringToUint(string)
* UintToString(uint)

These functions proved extremely useful when converting data types to be able to handle all of the logic behind the contract. 

### 2.2 The Compensation smart contract
The Compensation smart contract is a Solidity contract in which, once deployed, any agent can claim for a ticket, buy a ticket and then ask for a refunding (see the [Compensation contract](https://github.com/RebSolcia/BlockchainXItalo/blob/main/code/TicketNew.sol)).

The most important functions inside of this contract are (in logical order):
* **requestInfo(_stationDeparture, stationArrival, datetimeDeparture etc_)** that, given information over a train ticket sends an API call to our webservice to look for the most suitable solution inside of the Italo webservice. This function also stores a claim for such ticket inside of the RequestToPrice mapping. After having called the function, the customer who has called it is given a _counter number_ (which is equivalent to a personal key) that must be converted to then further interact with the contract in an encrypted way.
* **CounterToKeccak(_counter_)**, that must be used to retrieve the respective keccak-encoded version of the counter to obtain the _requestId_ to go on with the purchasing experience.
* **buyTicket(_requestId_)** is the function in which, after having made a claim for the ticket, the user must pay the required price of that ticket. If she pays too much, then the call is reverted. If it pays the right amount, the function uses the information inside of the RequestToPrice mapping to store the ticket info inside of a mapping called TicketsByTrainNumberByDatetime that, given a train number and a predicted datetime of arrival contains a list of the tickets belonging to the passengers inside that specific train. The function emits the relevant data for the passenger to, in case, ask for a claim (_trainNumber_ and _scheduledDatetimeArrival_) and then trashes the ticket claim inside of the RequestToPrice mapping, to save up some space.
* **checkDelay(_trainNumber, scheduledDatetimeArrival_)** calls our webservice to check whether a certain train has delayed. It also automatically refunds everyone whose train has delayed, proportionally to her initial payment and to the amount of delay. The function can be called one time for each "delay threshold" and can be called just when it has delayed of at least 20 minutes.

# HOW TO (TEST) - Run the code, step by step
## Step 0 - Before Running

## Step 1 - Deploy the contract in Remix

## Step 2 - Book a ticket

## Step 3 - Buy a ticket

## Step 4 - Ask for a refund


# HOW TO (PROD) - Run the code, step by step
## Step 0 - Before Running

## Step 1 - Deploy the contract in Remix

## Step 2 - Book a ticket

## Step 3 - Buy a ticket

## Step 4 - Ask for a refund
