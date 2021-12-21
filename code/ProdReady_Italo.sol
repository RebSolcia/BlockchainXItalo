pragma solidity ^0.5.0;

// Make sure to use the KOVAN TESTNET

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.5/ChainlinkClient.sol";
import "LibraryUtils.sol";

// The contract ItaloSellAndRefundService inherits from ChainLinkClient.sol and 
// uses the LibraryUtils library to make the conversions
contract ItaloSellAndRefundService_Prod is ChainlinkClient {
    
    //
    // CONSTRUCTOR
    //
    
    // A constructor is created in order to initialize the oracle address, the JobId (which is a Get>Bytes32),
    // the fee and the counter. They are all needed to make API calls. 
    constructor() public {
        setPublicChainlinkToken();
        owner = msg.sender;
        Oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "7401f318127148a894c00c292e486ffd";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }
    
    //
    // MODIFIERS
    //

    // Create a modifier onlyOwner that checks whether the request has been made by the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    //
    // STATE VARIABLES OF THE CONTRACT
    //

    // Define the state variables that will be needed inside of the contract for different purposes
    uint256 public currentPrice;
    address public owner;
    address public Oracle;
    bytes32 public jobId;
    uint256 public fee; 
    bytes32 public bytesdirisposta;
    string public response_string;
    uint public counter = 0;
    
    //
    // STRUCTS
    //

    // Ticket Struct that will store all of the information of a ticket
    struct Ticket {
        address payable owner;
        uint train_number;
        uint price;
        uint datetime_arrival_predicted;
        string station_departure;
        string station_arrival;
    }
    
    //
    // MAPPINGS
    //

    // RequestToPrice mapping is needed to check which price must be paid to get the ticket,
    // given the Keccak encoded version of the counter (obtained by using the CounterToKeccak function)
    mapping(bytes32 => string[]) public RequestToPrice;

    // TicketsByTrainNumberByDatetime is used for debugging purposes, to see whether the tickets are stored
    // given the train number and given the predicted datetime of arrival 
    mapping(uint => mapping(uint => Ticket[])) public TicketsByTrainNumberByDatetime;

    // DelayAsked ensures that the compensation has not been asked for a certain train at a certain threshold of delay
    mapping(uint => mapping(uint => mapping(uint => string))) public CompensationAsked;

    //
    // EVENTS
    //

    // TicketInfo emits a string related to the purchase of the ticket
    event TicketInfo (string successMessage);
    
    //
    // FUNCTIONS
    //

    // requestInfo: a function that is called to search for the ticket you want and store 
    // your claim for that ticket inside of the database
    function requestInfo(string memory _stationDeparture, string memory _stationArrival,
                         string memory _departureHour) public returns (bytes32 requestId) {

        // A request variable is created, following the fulfill function below
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the url to perform the GET request so that the request is built adaptively, 
        // given the parameters that are fed to the requestInfo function
        string memory query = string(abi.encodePacked("https://ef27-188-218-191-149.ngrok.io", //"https://455b-2001-b07-a3c-400a-b561-bc22-61b9-a720.ngrok.io",
                                                      "/request_info/?",
                                                      "departure_station=", _stationDeparture,
                                                      "&arrival_station=", _stationArrival,
                                                      "&departure_hour=", _departureHour));
        request.add("get", query);

        // Set the path to find the requred data in the API response
        request.add("path", "response");

        // Keep track of the requests with the counter, which is the variable that will allow the user to
        // first create a claim for a ticket and then buy it
        counter += 1;
        string memory counter_str = Converter.UintToString(counter);
        emit TicketInfo(string(abi.encodePacked("Your ticket has been successfully stored inside our database! To buy it, please insert the following request ID inside the CounterToKeccak function:", counter_str, ". After having retrieved the Keccak-encoded counter, go inside of the public mapping RequestToId and query the price of your ticket by inputting it these two parameters: the Keccak-encoded counter and the number 4. Once you have retrieved the price, please make sure to insert that specific number in FINNEY as the msg.value when buying a ticket.")));

        // Send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }

    // fulfill: function that actually fulfills the request forwarded by the requestInfo function.
    // You do not have to interact with it! These inputs are going to be fed by the requestInfo function itself.
    function fulfill(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {

        // Get the counter string
        string memory counter_str = Converter.UintToString(counter);
        // Create the keccak-encoded counter to store the ticket
        bytes32 counter_key = keccak256(abi.encode(counter_str));

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string_info = Converter.bytes32ToString(_response);

        // Split the string response_string based on underscores, so that you can index the response inside
        // the RequestToPrice mapping
        string[] memory response_list_info = Converter.split(response_string_info, "_");

        // Store, under the given counter_key (which is the keccak-encoded version of the counter),
        // the response string you get from the call
        RequestToPrice[counter_key] = response_list_info;
    }

    // Function used to turn strings into keccak bytes32
    function CounterToKeccak(string memory _counter) public pure returns (bytes32) {
        bytes32 kecca_hashed_counter = keccak256(abi.encode(_counter));
        return (kecca_hashed_counter);
    }

    // buyTicket: uses the keccak-encoded version of the counter to retrieve a certain ticket for a user and let her
    // pay for it and buy it. The msg.value when calling the buyTicket function must be greater or equal than the
    // price that you have retrieved previously by querying the RequestToPrice mapping, otherwise the transaction
    // gets reverted.
    function buyTicket(bytes32 _requestId) public payable {

        // Instantiate the actual price from string to uint to allow comparison with the msg.value
        uint actual_price = Converter.StringToUint(RequestToPrice[_requestId][4]);

        // Make sure that the msg.value is greater than the ETH price
        require(msg.value >= (actual_price*1000000000000000), "You have paid too little! Try again.");

        // Instantiate all of the variables that are needed to populate the ticket struct
        // by using the values that have been previously stored inside the RequestToPrice array
        address payable _owner = msg.sender;

        string memory _stationDeparture = RequestToPrice[_requestId][0];
        uint _datetimeArrivalPredicted = Converter.StringToUint(RequestToPrice[_requestId][1]);
        string memory _stationArrival = RequestToPrice[_requestId][2];
        uint _trainNumber = Converter.StringToUint(RequestToPrice[_requestId][3]);
        uint _price = Converter.StringToUint(RequestToPrice[_requestId][4]);

        // Emit an event telling the user in which case he's supposed to ask for a refund
        emit TicketInfo(string(abi.encodePacked("You have successfully bought your ticket from ", _stationDeparture, " to ", _stationArrival, ". The train ", RequestToPrice[_requestId][3] ," is scheduled to arrive at ", RequestToPrice[_requestId][1], ". Make sure to ask for a refund in case of delay! Thanks for choosing our service")));

        // Push the Ticket inside the Ticket array, given train number and given the datetime
        TicketsByTrainNumberByDatetime[_trainNumber][_datetimeArrivalPredicted].push(Ticket(_owner, _trainNumber, _price, _datetimeArrivalPredicted, _stationDeparture,  _stationArrival));

        // Remove the RequestId from the RequestToPrice mapping to avoid storing useless stuff, as the
        // ticket at this point has already been paid for
        delete RequestToPrice[_requestId];

        // Initialize the Delay array
        CompensationAsked[_trainNumber][_datetimeArrivalPredicted][30] = "False";
        CompensationAsked[_trainNumber][_datetimeArrivalPredicted][60] = "False";
        CompensationAsked[_trainNumber][_datetimeArrivalPredicted][90] = "False";
        CompensationAsked[_trainNumber][_datetimeArrivalPredicted][300] = "False";
    }


    // checkDelay: is meant to query the Italo's website given a certain train number to see whether it has delayed
    // with respect to its predicted datetime of arrival
    function checkDelay(string memory _trainNumber, string memory _expectedArr) public returns (bytes32 requestId) {

        // Check first whether the train has delayed of at least 20 mintues, otherwise it does not make
        // sense to go through all of the array iteration.
        uint _datetimeArrivalPredicted_Bytes = Converter.StringToUint(_expectedArr);
        require (now - _datetimeArrivalPredicted_Bytes > 1200, "The time elapsed since the predicted arrival of the train is below 20 minutes");

        // A request variable is created, following the fulfill_delay function below
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill_delay.selector);

        // Set the url to perform the GET request so that the request is built adaptively,
        // given the parameters that are fed to the requestInfo function
        string memory query = string(abi.encodePacked("https://ef27-188-218-191-149.ngrok.io", //"https://455b-2001-b07-a3c-400a-b561-bc22-61b9-a720.ngrok.io",
                                                      "/check_delay/?", 
                                                      "train_number=", _trainNumber,
                                                      "&expected_arr=", _expectedArr));
        request.add("get", query);

        // Set the path to find the requred data in the api response
        request.add("path", "response");

        // Send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }

    // fulfill_delay: function that actually fulfills the request forwarded by the requestInfo function.
    // You do not have to interact with it! These inputs are going to be fed by the requestInfo function itself.
    function fulfill_delay(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string_delay = Converter.bytes32ToString(_response);

        // Split the string response_string based on underscores, so that it is possible to parse it and
        // use the response variables to perform the further analysis for refunding
        string[] memory response_list_delay = Converter.split(response_string_delay, "_");

        // Create a number of different local variables to be used to get the refund
        string memory boolean = response_list_delay[0];
        uint _trainNumber_Delay = Converter.StringToUint(response_list_delay[1]);
        uint _datetimeArrivalPredicted_Delay = Converter.StringToUint(response_list_delay[2]);
        uint _minutesOfDelay = Converter.StringToUint(response_list_delay[3]);
        uint length_ticketlist = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay].length;

        // If the train has delayed:
        if (keccak256(abi.encodePacked(boolean))==keccak256(abi.encodePacked("True"))) {

            // If the train has delayed by more than 30 minutes and less than 60 minutes, you will get a refund of 30%
            if ((30 <= _minutesOfDelay) && (_minutesOfDelay < 60) &&
                (keccak256(abi.encodePacked(CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][30])) == keccak256(abi.encodePacked("False")))) {
                // Iterate through all of the ticket list, given the train number and the predicted arrival keys
                for (uint i=0; i < length_ticketlist; i++){
                    // Get the ticket indexed by i
                    Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                    // Get the owner of the ticket indexed by i
                    address payable owner_to_be_repaid = this_ticket.owner;
                    // Calculate the amount of be repaid as a percentage of the price of the ticket indexed by i
                    uint amount_to_be_repaid = ((this_ticket.price * 30) / 100);
                    // Transfer such amount to the owner of the ticket
                    owner_to_be_repaid.transfer(amount_to_be_repaid*1000000000000000);
                    // Decrease the price of the ticket by the amount that has been already refunded
                    TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i].price -= amount_to_be_repaid;
                }
                CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][30] = "True";
            } else if ((60 <= _minutesOfDelay) && (_minutesOfDelay < 90) &&
                    (keccak256(abi.encodePacked(CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][60])) == keccak256(abi.encodePacked("False")))) {
                for (uint i=0; i < length_ticketlist; i++){
                    Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                    address payable owner_to_be_repaid = this_ticket.owner;
                    uint amount_to_be_repaid = ((this_ticket.price * 60) / 100);
                    owner_to_be_repaid.transfer(amount_to_be_repaid*1000000000000000);
                    TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i].price -= amount_to_be_repaid;
                }
                CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][60] = "True";
            } else if ((90 <= _minutesOfDelay) && (_minutesOfDelay < 120) &&
                    (keccak256(abi.encodePacked(CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][90])) == keccak256(abi.encodePacked("False")))) {
                for (uint i=0; i < length_ticketlist; i++){
                    Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                    address payable owner_to_be_repaid = this_ticket.owner;
                    uint amount_to_be_repaid = ((this_ticket.price * 90) / 100);
                    owner_to_be_repaid.transfer(amount_to_be_repaid*1000000000000000);
                    TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i].price -= amount_to_be_repaid;
                }
                CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][90] = "True";
            } else if ((_minutesOfDelay > 300) && (keccak256(abi.encodePacked(CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][300])) == keccak256(abi.encodePacked("False")))) {
                // If the train has delayed by more than 300 minutes, then it is not possible to claim for
                // further refunding and the train tickets indexed by a certain train number and a certain arrival predicted
                // are just deleted, to save up some space
                delete TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay];
                CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][300] = "True";
                // Delete the refunding mapping because it wouldn't make sense to have it there
                delete CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][30];
                delete CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][60];
                delete CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][90];
                delete CompensationAsked[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][300];
            }
        }
    }

    function ItaloWithdrawal(uint amount) onlyOwner public returns (bool) {
        require(amount < address(this).balance);
        msg.sender.transfer(amount);
        return true;
    }
}