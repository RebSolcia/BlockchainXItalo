pragma solidity ^0.6.0;

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.6/ChainlinkClient.sol";

import "https://github.com/Arachnid/solidity-stringutils/blob/master/src/strings.sol";


//contracts are like classes
//this Chainlink example inherits from ChainlinkClient

contract ChainlinkExample is ChainlinkClient {
    
    //define state variables stored on the block chain
    uint256 public currentPrice;
    address public owner;
    address public Oracle;
    bytes32 public jobId;
    uint256 public fee; 
    // Environmental variables
    address public contractOwner;

    // Structs
    struct Ticket {
        address payable owner;
        bytes32 ticket_id;
        uint train_number;
        uint price;
        uint datetime_departure;
        uint datetime_arrival_predicted;
        string station_departure; // encode stations by number 
        string station_arrival; // encode stations by number 
    }

    // Mappings
    mapping(uint => mapping(uint => Ticket[])) tickets_byTrain_byTime;
    
    // Constructor is run at the time of contract creating
    constructor() public {
        contractOwner = msg.sender;
        setPublicChainlinkToken();
        owner = msg.sender;
        Oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    // Events
    event TicketEmission(bytes32 ticketId);

    //function below creates a Chainlink API request to get a price
    //only the owner of the contract can call this function
    function requestPrice() public returns (bytes32 requestId)
    {
        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        //set the url to perform the GET request
        request.add("get", "https://9e37-93-66-104-18.ngrok.io/buy_ticket/?owner=0x6a522cf77C1B37540bBAB6995783a0B11d7F3d36&ticket_id=7329515239218365070");
        //set the path to find the requred data in the api response
        request.add("path", "price");
        //multiply the results by 100 to remove decimals
        request.addInt("times", 100);
        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }
    
    function fulfill(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId) 
    {
        currentPrice = _price;
    }


    function BuyTicket(uint train_number, uint price, uint datetime_departure, uint datetime_arrival_predicted, string memory station_departure, string memory station_arrival) public returns(bytes32 requestId){
        
        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillBuyTicket.selector);

        //set the url to perform the GET request
        request.add("get", "pathtorequestOfBuyingTickets");

        //set the path to find the requred data in the api response
        request.add("path", "datetime_format");

        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    
    }
    // Client has to input everything (price, datetime ecc)
    // Transaction
        //Store ticket in the mapping [train_number]=>[datetime_of_arrival]=>ticket
    // Ask refund (train_number, datetime_of_arrival)
        // require (-0h <now - datetime_of_arrival< 2h, "Try again with another key")
        // call oracle webscraping ==>bool
            //if true iterare 
    // function check delay 


    function fulfillBuyTicket(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId) {
        currentPrice = _price;
        
        Ticket memory ticket_to_be_bought = tickets_byTrain_byTime[_trainNumber][counter];

        // Insert a control for owner to exist

        ticket_to_be_bought.owner = payable(msg.sender);
        uint ticket_price = ticket_to_be_bought.price;
        //(bool sent, bytes memory data) = contractOwner.call{value: ticket_price}("You have just paid Italo for your ticket!");

        // Require that the money has actually been sent to then change the owner of the ticket
        //require(sent, "Failed to send Ether");

        tickets_database[contractOwner][ticket_to_be_bought.ticket_id].owner = ticket_to_be_bought.owner;

        emit TicketEmission(ticket_to_be_bought.ticket_id);
        
    }
    
}