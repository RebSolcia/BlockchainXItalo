"""This script is meant to run a webservice"""

from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.exception_handlers import request_validation_exception_handler

import logging
import os
import uvicorn
import sqlite3
import numpy as np

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

# Change the following path
ser = Service("../chromedriver.exe")

import time
import datetime

# Instantiate the first variables and exception handlers

VERSION = "0.0.1"

logger = logging.getLogger(__name__)

tags_metadata = [
    {
        "name": "upload",
        "description": "Endpoints that perform the upload of tickets."
    },
    {
        "name": "seeTicket",
        "description": "Endpoints that perform the broadcasting of tickets."
    },
    {
        "name": "buyTicket",
        "description": "Endpoints that allows the purchase of tickets."
    },
    {
        "name": "searchTicket",
        "description": "Endpoints that allows the search of tickets."
    },
    {
        "name": "checkDelay",
        "description": "Endpoints that allows to check if a train had a delay of more than 60 minutes."
    },
    {
        "name": "fakeTicketSearch",
        "description": "Endpoints that allows to simulate the response obtained by calling the searchTicket function."
    },
    {
        "name": "fakeDelay",
        "description": "Endpoints that allows to simulate the response obtained by calling the checkDelay function."
    }
]

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


# Main GET functions

@app.get(
    path="/request_info/",
    tags=["searchTicket"],
    summary="Search for Tickets",
    description="Main method to search for tickets on Italo's website."
)
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

    options = webdriver.ChromeOptions()
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)

    driver = webdriver.Chrome(service=ser,
                              options=options)  # or webdriver.Chrome(executable_path=local_path_of_driver, options=options)
    driver.get(train_URL)

    search_box_from = driver.find_element_by_xpath(
        '/html/body/main/section[3]/div[2]/form/div[1]/div/table/tbody/tr[1]/td[1]/fieldset/div/input[1]').send_keys(
        departure_station)
    search_box_to = driver.find_element_by_xpath(
        '/html/body/main/section[3]/div[2]/form/div[1]/div/table/tbody/tr[1]/td[3]/fieldset/div/input[1]').send_keys(
        arrival_station)

    button = driver.find_element_by_xpath(
        '/html/body/main/section[3]/div[2]/form/div[1]/div/table/tbody/tr[1]/td[4]/div/a')
    webdriver.ActionChains(driver).click_and_hold(button).perform()
    driver.execute_script("arguments[0].click();", button)

    try:
        element_present = EC.presence_of_element_located(
            (By.XPATH, '/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr[1]/td[1]/p[1]'))
        WebDriverWait(driver, 15).until(element_present)
    except TimeoutException:
        return "Timeout"

    num_options = len(driver.find_elements_by_xpath("/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr"))
    if num_options == 0:
        return f"Sorry, no routes available from {departure_station} to {arrival_station}"

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

    train_number = driver.find_element_by_xpath(
        f'/html/body/main/section[3]/div[3]/div[2]/table/tbody/tr[{choice}]/td[4]/p[2]').get_attribute("innerText")

    departure_station_new = departure_station[:2]
    arrival_station_new = arrival_station[:2]

    price = np.random.randint(50, 100)

    ticket = f"{departure_station_new}_{unix_arrival}_{arrival_station_new}_{train_number}_{price}"

    return {"response": ticket}


@app.get(
    path="/fake_ticket_search/",
    tags=["fakeTicketSearch"],
    summary="Fake Ticket Search",
    description="Main method to simulate response from calling the searchTicket function."
)
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

    departure_station_new = departure_station[:2]
    arrival_station_new = arrival_station[:2]

    ticket = f"{departure_station_new}_{unix_arrival}_{arrival_station_new}_{train_number}_{price_rounded}"

    return {"response": ticket}


@app.get(
    path="/check_delay/",
    tags=["checkDelay"],
    summary="Check Delay",
    description="Main method to check if a train had a delay of more than 60 minutes."
)
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
    # Scrape Italo's website to check if train has a delay
    driver = webdriver.Chrome(service=ser)  # or webdriver.Chrome(executable_path=local_path_of_driver)
    base_URL = 'https://italoinviaggio.italotreno.it/en/train'
    driver.get(base_URL + '/' + str(train_number))

    try:
        delay = driver.find_element_by_xpath(
            '/html/body/div[2]/section/div/div/div[1]/div/div/div[3]/span[2]').get_attribute("innerText")
        if (int(delay.split()[0])) >= 30:
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
    print("INFO: Run test at http://localhost:400/upload_tickets/?owner=0x14408Ee49aC5B4BCce27E8699fEaaBD15e222D12"
          "&train_number=7138&price=30&datetime_departure=40&datetime_arrival_predicted=50&station_departure=Venice"
          "&station_arrival=Florence&n_tickets=20")

    uvicorn.run(app="webservice:app", host="localhost", port=400)
