"""This script is meant to run a webservice"""

import datetime

from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.exception_handlers import request_validation_exception_handler

import logging
import os
import uvicorn
import sqlite3

# Instantiate the first variables and exception handlers

VERSION = "0.0.1"

logger = logging.getLogger(__name__)

tags_metadata = [
    {
        "name": "upload",
        "description": "Endpoints that perform the upload of tickets."
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
    path="/upload_tickets/",
    tags=["upload"],
    summary="Upload Tickets",
    description="Main method to upload tickets for Italo."
)
async def upload_database(
        owner: str = Query(
            default=...,
            description="Owner of the ticket.",
        ),
        train_number: int = Query(
            default=...,
            description="Number of the train that is uploaded."
        ),
        price: int = Query(
            default=...,
            description="Price of the ticket."
        ),
        datetime_departure: int = Query(
            default=...,
            description="Time of departure of the train."
        ),
        datetime_arrival_predicted: int = Query(
            default=...,
            description="Predicted time of arrival."
        ),
        station_departure: str = Query(
            default=...,
            description="Station of departure."
        ),
        station_arrival: str = Query(
            default=...,
            description="Station of arrival."
        ),
        n_tickets: int = Query(
            default=...,
            description="Number of tickets to be uploaded."
        ),
):
    con = sqlite3.connect("Italo.db")
    cur = con.cursor()
    cur.execute("""CREATE TABLE IF NOT EXISTS Italo
                   (owner CHAR, ticket_id INT, train_number INT, price INT, 
                   datetime_departure INT, datetime_arrival_predicted INT,
                   station_departure CHAR, station_arrival CHAR)
                   """)
    con.commit()

    data = []
    data_dictionary = []

    for i in range(n_tickets):
        row = (i, train_number, price, datetime_departure, datetime_arrival_predicted, station_departure,
               station_arrival)
        ticket_id = hash(row)
        ticket_row = (owner, ticket_id, train_number, price, datetime_departure, datetime_arrival_predicted,
                      station_departure, station_arrival)
        data.append(ticket_row)

        ticket_dictionary = {"owner": owner,
                             "ticket_id": ticket_id,
                             "train_number": train_number,
                             "price": price,
                             "datetime_departure": datetime_departure,
                             "datetime_arrival_predicted": datetime_arrival_predicted,
                             "station_departure": station_departure,
                             "station_arrival": station_arrival
                             }

        data_dictionary.append(ticket_dictionary)

    query = f"""INSERT INTO Italo 
                (owner, ticket_id, train_number, price, datetime_departure, datetime_arrival_predicted,
                station_departure, station_arrival)
                
                VALUES(?, ?, ?, ?, ?, ?, ?, ?);
            """
    cur.executemany(query, data)

    con.commit()
    con.close()

    return_json = data_dictionary[0]

    return return_json


@app.get("/see_your_ticket/")
async def see_your_ticket(owner: str,
                          ticket_id: int):
    # Access the database by querying it with both the owner and the ticket_id keys
    # It should return the info (check whether there is some Oracle that can actually return lists)

    con = sqlite3.connect("Italo.db")
    cur = con.cursor()

    literal = owner[2:]

    query = f"""SELECT *
               FROM Italo i
               WHERE 1==1
               AND i.ticket_id == {ticket_id}
               AND i.owner == "0x{literal}"
            """

    cur.execute(query)

    con.commit()
    ticket = cur.fetchall()
    con.close()

    json_ticket = {
        "owner": ticket[0][0],
        "ticket_id": ticket[0][1],
        "train_number": ticket[0][2],
        "price": ticket[0][3],
        "datetime_departure": ticket[0][4],
        "datetime_arrival": ticket[0][5],
        "station_departure": ticket[0][6],
        "station_arrival": ticket[0][7],
    }

    return json_ticket


@app.get("/buy_ticket/")
async def buy_ticket(owner: str,
                     ticket_id: int):
    # Access the database and get the first available ticket and change the owner
    return


if __name__ == "__main__":
    print("INFO: Run test at http://localhost:400/upload_tickets/?owner=0x14408Ee49aC5B4BCce27E8699fEaaBD15e222D12"
          "&train_number=7138&price=30&datetime_departure=40&datetime_arrival_predicted=50&station_departure=Venice"
          "&station_arrival=Florence&n_tickets=20")

    uvicorn.run(app="webservice:app", host="localhost", port=400)
