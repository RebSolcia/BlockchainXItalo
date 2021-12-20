"""This script is meant to run a webservice"""

import logging
import os
import uvicorn
import time
import datetime
import numpy as np

from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.exception_handlers import request_validation_exception_handler

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

from web3 import Web3

# IMPORTANT: Change the following path to local chromedriver instance
exe_path = os.path.join(os.getcwd(), "chromedriver.exe")
ser = Service(exe_path)

# Instantiate the first variables and exception handlers
VERSION = "0.0.1"

logger = logging.getLogger(__name__)

tags_metadata = [
    {
        "name": "searchTicket",
        "description": "Endpoint that allows the search of tickets and retrieval of ticket information."
    },
    {
        "name": "checkDelay",
        "description": "Endpoint that allows checking if a train had a delay of more than 60 minutes."
    },
    {
        "name": "fakeTicketSearch",
        "description": "Endpoint that allows to simulate the response obtained by calling the searchTicket function."
    },
    {
        "name": "fakeDelay",
        "description": "Endpoint that allows to simulate the response obtained by calling the checkDelay function."
    }
]

# Intitialize FastAPI 
app = FastAPI(
    title="BlockchainXItalo",
    description="A webservice that interacts with Italo through use of ChainLink and Ethereum blockchain.",
    version=VERSION,
    openapi_tags=tags_metadata,
)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
        request: Request,
        exc: RequestValidationError
):
    status_code = "KO"
    status_description = "FastAPI Validation Error"
    json_logger = {
        "status": {
            "code": status_code,
            "description": status_description,
        },
        "verbose": {
            "requestDateTime": datetime.uctnow().strftime("%Y-%m-%d %H:%M:%S"),
            "scriptPath": os.path.dirname(os.path.abspath(__file__)),
            "programVersion": VERSION,
            "client_url": str(request.url),
            "client_host": request.client.host,
            "client_port": request.client.port,
        },
        "exception": str(exc)
    }

    logger.error("FastAPI Validation Error")

    return await request_validation_exception_handler(request, exc)


# Function to retrieve the USD price of ETH
def getETHprice(ticket_price):
    web3 = Web3(Web3.HTTPProvider('https://kovan.infura.io/v3/abde9f2d44754a6f80435bff911eb484'))
    abi = '[{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"description","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint80","name":"_roundId","type":"uint80"}],"name":"getRoundData","outputs":[{"internalType":"uint80","name":"roundId","type":"uint80"},{"internalType":"int256","name":"answer","type":"int256"},{"internalType":"uint256","name":"startedAt","type":"uint256"},{"internalType":"uint256","name":"updatedAt","type":"uint256"},{"internalType":"uint80","name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"latestRoundData","outputs":[{"internalType":"uint80","name":"roundId","type":"uint80"},{"internalType":"int256","name":"answer","type":"int256"},{"internalType":"uint256","name":"startedAt","type":"uint256"},{"internalType":"uint256","name":"updatedAt","type":"uint256"},{"internalType":"uint80","name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"version","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]'
    addr = '0x9326BFA02ADD2366b30bacB125260Af641031331'
    contract = web3.eth.contract(address=addr, abi=abi)
    latestData = contract.functions.latestRoundData().call()
    ETH_price_in_USD = latestData[1] / 100000000
    ticket_price_in_ETH = (1 / ETH_price_in_USD) * ticket_price
    ticket_price_in_FINNEY = ticket_price_in_ETH * 1000
    ticket_price_in_FINNEY_rounded = int(ticket_price_in_FINNEY)
    return ticket_price_in_FINNEY_rounded


# Main GET functions

@app.get(
    path="/request_info/",
    tags=["searchTicket"],
    summary="Search for Tickets",
    description="Main method to search for tickets on Italo's website."
)
# Defininig search_ticket function which simulates the purchasing of a ticket through scraping Italo's website
async def search_ticket(
        request: Request,

        departure_station: str = Query(
            default=...,
            description="Station of departure."
        ),
        arrival_station: str = Query(
            default=...,
            description="Station of arrival."
        ),
        departure_hour: int = Query(
            default=0,
            description="Min hour of the departure."
        ),
):
    # Scrape Italo's website to get first available train after the specified hour
    train_URL = 'https://www.italotreno.it/en/destinations-timetable/trains-schedules'

    # Start webdriver on Italo's Website
    options = webdriver.ChromeOptions()
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)

    driver = webdriver.Chrome(service=ser,
                              options=options)  # or webdriver.Chrome(executable_path=local_path_of_driver, options=options)
    driver.get(train_URL)

    # Input requested departure station and arrival station
    search_box_from = driver.find_element_by_xpath(
        '/html/body/main/section[3]/div[2]/form/div[1]/div/table/tbody/tr[1]/td[1]/fieldset/div/input[1]').send_keys(
        departure_station)
    search_box_to = driver.find_element_by_xpath(
        '/html/body/main/section[3]/div[2]/form/div[1]/div/table/tbody/tr[1]/td[3]/fieldset/div/input[1]').send_keys(
        arrival_station)

    # Search for train connections
    button = driver.find_element_by_xpath(
        '/html/body/main/section[3]/div[2]/form/div[1]/div/table/tbody/tr[1]/td[4]/div/a')
    webdriver.ActionChains(driver).click_and_hold(button).perform()
    driver.execute_script("arguments[0].click();", button)

    # Wait for page to be loaded
    try:
        element_present = EC.presence_of_element_located(
            (By.XPATH, '/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr[1]/td[1]/p[1]'))
        WebDriverWait(driver, 15).until(element_present)
    except TimeoutException:
        return "Timeout"

    num_options = len(driver.find_elements_by_xpath("/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr"))
    if num_options == 0:
        return f"Sorry, no routes available from {departure_station} to {arrival_station}"

    # Choose best train connection depending on requested time
    timing = []
    departure_hour = str(departure_hour) + "00"
    for i in range(1, num_options + 1):
        time_dep = driver.find_element_by_xpath(
            f"/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr[{i}]/td[1]/p[1]").get_attribute("innerText")
        time_arr = driver.find_element_by_xpath(
            f"/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr[{i}]/td[2]/p[1]").get_attribute("innerText")
        if (int(time_dep[:2] + time_dep[3:]) - int(departure_hour)) >= 0:
            timing.append((i, time_dep, time_arr))
            break

    if len(timing) == 0:
        return f"Sorry, no available trains after {departure_hour[:-2]}:00"

    x = 0
    choice = timing[x][0]

    # Converting time of departure and time of arrival of connection to unix format
    time_of_departure, time_of_arrival = timing[x][1:]
    today = datetime.date.today()
    day_dep = today.day + 1
    if (int(time_of_arrival.split(":")[0]) - int(time_of_departure.split(":")[0])) < 0:
        day_arr = day_dep + 1
    else:
        day_arr = day_dep

    datetime_arr = datetime.datetime(today.year, today.month, day_arr, int(time_of_arrival.split(":")[0]),
                                     int(time_of_arrival.split(":")[1]))
    unix_arrival = round(time.mktime(datetime_arr.timetuple()))

    # Retrieve train number
    train_number = driver.find_element_by_xpath(
        f'/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr[{choice}]/td[4]/p[2]').get_attribute("innerText")

    # Encoding Stations
    stations = {
        "Milano Centrale": "MIL",
        "Roma Termini": "ROM",
        "Napoli Centrale": "NAP",
        "Torino Porta Nuova": "TOR",
        "Firenze S.M.Novella": "FIR",
        "Bologna Centrale": "BOL",
        "Agropoli": "AGR",
        "Bari Centrale": "BAR",
        "Barletta": "BRL",
        "Benevento": "BNV",
        "Bergamo": "BRG",
        "Bisceglie": "BSC",
        "Bolzano": "BZN",
        "Brescia": "BRS",
        "Caserta": "CAS",
        "Conegliano": "CON",
        "Desenzano": "DES",
        "Ferrara": "FER",
        "Foggia": "FOG",
        "Genova Brignole": "GBR",
        "Genova Piazza Principe": "GPP",
        "Lamezia Terme C": "LTC",
        "Latisana-Lignano-Bib": "LTB",
        "Maratea": "MRT",
        "Milano Rho Fiera": "MRF",
        "Milano Rogoredo": "MLR",
        "Molfetta": "MLF",
        "Monfalcone": "MNF",
        "Napoli Afragola": "NPA",
        "Padova": "PDV",
        "Paola": "PAO",
        "Peschiera": "PES",
        "Pordenone": "PRN",
        "Portogruaro-Caorle": "PGC",
        "Reggio Calabria": "RGC",
        "Reggio Emilia AV": "REA",
        "Roma Tiburtina": "RMT",
        "Rosarno": "ROS",
        "Rovereto": "RVR",
        "Rovigo": "RVG",
        "Salerno": "SLR",
        "Sapri": "SPR",
        "Scalea": "SCL",
        "Torino Porta Susa": "TPS",
        "Trani": "TRA",
        "Trento": "TRN",
        "Treviso Centrale": "TRV",
        "Trieste Centrale": "TRI",
        "Udine": "UDI",
        "Vallo d. Lucania": "VDL",
        "Venezia Mestre": "VZM",
        "Venezia S.Lucia": "VSL",
        "Verona Porta Nuova": "VPN",
        "Vibo-Pizzo": "VBP",
        "Vicenza": "VIC",
        "Villa S.Giovanni": "VSG",
    }

    # Shorten departure station and arrival station for output
    departure_station_new = stations[departure_station]
    arrival_station_new = stations[arrival_station]
    # Choose random price between 50 and 100 since retrieving real price would have resulted in chainlink timeout due
    # to slow loading response time of website
    price = np.random.randint(50, 100)

    price_rounded_finney = int(getETHprice(price))

    # fill ticket with information
    ticket = f"{departure_station_new}_{unix_arrival}_{arrival_station_new}_{train_number}_{price_rounded_finney}"

    driver.quit()

    return {"response": ticket}


@app.get(
    path="/fake_ticket_search/",
    tags=["fakeTicketSearch"],
    summary="Fake Ticket Search",
    description="Main method to simulate response from calling the searchTicket function."
)
# Simulation of search_ticket where every piece of ticket information can be chosenn by user and is returned in
# correct format
async def fake_ticket_search(
        request: Request,

        # departure_station, arrival_station, time_of_departure, time_of_arrival, price, train_number
        departure_station: str = Query(
            default=...,
            description="Station of departure."
        ),
        arrival_station: str = Query(
            default=...,
            description="Station of arrival."
        ),
        train_number: str = Query(
            default=...,
            description="Train number."
        ),
        time_of_departure: str = Query(
            default=...,
            description="Time of departure (hh:mm)."
        ),
        time_of_arrival: str = Query(
            default=...,
            description="Time of expected arrival (hh:mm)."
        ),
        price: str = Query(
            default=...,
            description="Price of one ticket (e.g. 59.90)."
        )
):
    # Converting time of departure and time of arrival of connection to unix format
    today = datetime.date.today()
    day_dep = today.day + 1
    if (int(time_of_arrival.split(":")[0]) - int(time_of_departure.split(":")[0])) < 0:
        day_arr = day_dep + 1
    else:
        day_arr = day_dep
    datetime_arr = datetime.datetime(today.year, today.month, day_arr, int(time_of_arrival.split(":")[0]),
                                     int(time_of_arrival.split(":")[1]))
    unix_arrival = round(time.mktime(datetime_arr.timetuple()))

    price_rounded = int(float(price[:-2]))
    price_rounded_finney = int(getETHprice(price_rounded))

    departure_station_new = departure_station[:2]
    arrival_station_new = arrival_station[:2]

    ticket = f"{departure_station_new}_{unix_arrival}_{arrival_station_new}_{train_number}_{price_rounded_finney}"

    return {"response": ticket}


@app.get(
    path="/check_delay/",
    tags=["checkDelay"],
    summary="Check Delay",
    description="Main method to check if a train had a delay of more than 60 minutes."
)
# Checking if train is delayed by train number through webscraping
async def check_delay(
        request: Request,

        train_number: str = Query(
            default=...,
            description="Train number."
        ),
        expected_arr: str = Query(
            default=...,
            description="Unix datetime of expected arrival."
        )
):
    # Initialize webdriver on Italo website
    driver = webdriver.Chrome(service=ser)  # or webdriver.Chrome(executable_path=local_path_of_driver)
    base_URL = 'https://italoinviaggio.italotreno.it/en/train'
    driver.get(base_URL + '/' + str(train_number))

    # Check if train is currently running and delayed
    delay_thresh = 30  # threshhold for which function checks if delayed
    try:
        delay = driver.find_element_by_xpath(
            '/html/body/div[2]/section/div/div/div[1]/div/div/div[3]/span[2]').get_attribute("innerText")
        if (int(delay.split()[0])) >= delay_thresh:
            return {"response": f"True_{train_number}_{expected_arr}_{delay}"}
        else:
            return {"response": f"False_{train_number}_{expected_arr}_{delay}"}
    except:
        return {"response": f"False_{train_number}_{expected_arr}_00"}


@app.get(
    path="/fake_delay/",
    tags=["fakeDelay"],
    summary="Fake Delay",
    description="Main method to simulate response from calling the checkDelay function."
)
# Simulation of check_delay function where user can input train number and length of delay
async def fake_delay(
        request: Request,
        train_number: str = Query(
            default=...,
            description="Train number."
        ),
        expected_arr: str = Query(
            default=...,
            description="Unix datetime of expected arrival."
        ),
        delay: str = Query(
            default=...,
            description="Minutes of delay."
        ),
        thr: str = Query(
            default=60,
            description="Threshold for delay, default is 60 minutes."
        )

):
    if delay >= thr:
        return {"response": f"True_{train_number}_{expected_arr}_{delay}"}
    else:
        return {"response": f"False_{train_number}_{expected_arr}_{delay}"}


if __name__ == "__main__":
    print("INFO: To read the documentation: http://localhost:400/docs")

    uvicorn.run(app="webservice:app", host="localhost", port=400)
