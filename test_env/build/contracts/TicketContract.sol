// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract TicketInsurance{

    // Environmental variables
    address public contractOwner;

    // Mappings

    // Constructors
    constructor() {contractOwner = msg.sender;}

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


    mapping(address => mapping(bytes32 => Ticket)) tickets_database;
    mapping(uint => Ticket[]) tickets_database_by_train_number;

    // Events

    event TicketEmission(bytes32 ticketId);

    // Functions

    function UploadTickets(uint _trainNumber, uint _price, uint _datetimeDeparture, 
                           uint _datetimeArrivalPredicted, string memory _stationDeparture, 
                           string memory _stationArrival, uint _totalNumberTickets) public {
        require(msg.sender == contractOwner, "You're not Italo. You cannot upload any ticket.");
        uint total_number = _totalNumberTickets;
        address payable Italo = payable(msg.sender);
        for (uint i=0; i<total_number; i++){
            bytes32 _id = keccak256(abi.encodePacked(i, _trainNumber, _datetimeDeparture, _stationDeparture, _stationArrival)); 
            tickets_database[Italo][_id] = Ticket(Italo, _id, _trainNumber, _price, _datetimeDeparture, _datetimeArrivalPredicted, _stationDeparture,  _stationArrival);
            tickets_database_by_train_number[_trainNumber].push(Ticket(Italo, _id, _trainNumber, _price, _datetimeDeparture, _datetimeArrivalPredicted, _stationDeparture,  _stationArrival));
            emit TicketEmission(_id);
        }        
    }

    function SeeYourTicket(bytes32 _ticketId) public view returns (uint, uint, uint, string memory, uint, string memory) {
        require(tickets_database[msg.sender][_ticketId].owner == msg.sender, "This ticket doesn't belong to you! Try to re-type the ticketId!");
        address owner = msg.sender;
        bytes32 ticket_id = _ticketId;
        uint myticket_trainNumber = tickets_database[owner][ticket_id].train_number;
        uint myticket_price = tickets_database[owner][ticket_id].price;
        uint myticket_datetimeDeparture = tickets_database[owner][ticket_id].datetime_departure;
        string memory myticket_stationDeparture = tickets_database[owner][ticket_id].station_departure;
        uint myticket_datetimeArrivalPredicted = tickets_database[owner][ticket_id].datetime_arrival_predicted;
        string memory myticket_stationArrival = tickets_database[owner][ticket_id].station_arrival;
        
        return (myticket_trainNumber, myticket_price, myticket_datetimeDeparture, myticket_stationDeparture, myticket_datetimeArrivalPredicted, myticket_stationArrival);
    }

    function BuyTicket(uint _trainNumber) public returns(bytes32){
        uint counter = 0;
        Ticket memory ticket_to_be_bought = tickets_database_by_train_number[_trainNumber][counter];
        while ((ticket_to_be_bought.owner != contractOwner) && (counter < tickets_database_by_train_number[_trainNumber].length)) {
            counter += 1;
            ticket_to_be_bought = tickets_database_by_train_number[_trainNumber][counter];                    
        }

        // Insert a control for owner to exist

        ticket_to_be_bought.owner = payable(msg.sender);
        uint ticket_price = ticket_to_be_bought.price;
        //(bool sent, bytes memory data) = contractOwner.call{value: ticket_price}("You have just paid Italo for your ticket!");
        
        // Require that the money has actually been sent to then change the owner of the ticket
        //require(sent, "Failed to send Ether");

        tickets_database[contractOwner][ticket_to_be_bought.ticket_id].owner = ticket_to_be_bought.owner;

        emit TicketEmission(ticket_to_be_bought.ticket_id);
    }

    function Refunding(Ticket memory _ticket) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        address payable ticket_owner = _ticket.owner;
        uint ticket_price = _ticket.price;
        (bool sent, bytes memory data) = ticket_owner.call{value: ticket_price}("You have been refunded for the delay");
        require(sent, "Failed to send Ether");
    }

    function ReturnRefundTickets(uint _trainNumber) public{
        uint counter_tickets = tickets_database_by_train_number[_trainNumber].length;
        for (uint i=0; i<counter_tickets; i++){
            Refunding(tickets_database_by_train_number[_trainNumber][i]);
            //tickets_database_by_train_number[_trainNumber][i] = ;
        }
    }

    //function CheckDelay(uint _trainNumber) public view returns (bool){
    //
    //} 
}

// Ticket Contract, in general:
// 1. Define functionalities
// 2. Contract communicating with Oracles

// Data:
// 1. Ticket information: ticket_id, number of the train, datetime of departure, datetime of arrival (planned), datetime of arrival (actual),
//                        departure station, arrival station, price, msg.sender, our wallets (reimbursment wallet - profit wallet),
//                        hash(id and train id).

// ORACLE DATA

// Functions:
// 1. UploadTickets_ByItalo(number of train, datetime of departure, datetime of arrival(planned), departure station, arrival station, price, NUMBER OF TICKETS)
// 2. BuyTicket(msg.sender, number of the train, datetime of departure, departure station, arrival station, NUMBER_TICKET)
// 3. CheckYourTicket(msg.sender) it will return your ticket information
// 4. GetOracleData() must raise an event calling the CheckRefund function and must feed the CheckRefund with train number and true arrival time
// 5. CheckRefund(train number, true arrival time) and will call the Refund for all the ticket owners that respect the criterion
// 6. Refund(ticket owner, ticket id) will send back the money to the owner

// REQUIREMENTS and returns:
// 1. Sanity check for datetime (check for consistency)
// 2. Error message for any other inconsistency in stations, prices

// More ideas:
// 1. Checking whether the person was actually on the train
// 2. Further developments for seats class (economy, business) and refund proportional
// 3. Add other stop stations


// INTRODUCE TIME:
// Use your own Oracle that keeps calling the contract
// We want to auto-refund. The off-chain Oracle has a loop (open the web3 connection) - while true - via web3 we check for some event 
// (query for train time) make a call from the contract
// Automatically refund: keep checking the train API and from outside I call everybody