import os
from datetime import date, timedelta

import boto3


def lambda_handler(event, context):
    recipient = os.environ["RECIPIENT"]
    today = date.today()
    yesterday = today - timedelta(days=1)
    month_start = today.replace(day=1)
    cost_explorer = boto3.client("ce")
    ses = boto3.client("ses")

    def total_cost(start, end):
        result = cost_explorer.get_cost_and_usage(
            TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
        )
        amount = result["ResultsByTime"][0]["Total"]["UnblendedCost"]
        return amount["Amount"], amount["Unit"]

    try:
        daily_amount, currency = total_cost(yesterday, today)
        month_amount, _ = total_cost(month_start, today)
        body = (
            f"AWS daily billing report\n\n"
            f"Date: {yesterday.isoformat()}\n"
            f"Daily unblended cost: {daily_amount} {currency}\n"
            f"Month-to-date unblended cost: {month_amount} {currency}\n\n"
            "Cost Explorer data can be delayed by up to 24 hours."
        )
    except Exception as error:
        body = f"AWS daily billing report could not retrieve Cost Explorer data:\n{error}"

    ses.send_email(
        Source=recipient,
        Destination={"ToAddresses": [recipient]},
        Message={
            "Subject": {"Data": f"AWS billing report — {yesterday.isoformat()}", "Charset": "UTF-8"},
            "Body": {"Text": {"Data": body, "Charset": "UTF-8"}},
        },
    )
    return {"status": "sent"}
