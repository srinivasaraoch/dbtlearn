def model(dbt, session):
    dbt.config(materialized='table')

    # Load TRIP_BOOKINGS table into pandas DataFrame
    df = dbt.ref("trip_bookings").to_pandas()
    df = df.sort_values(by=["TRAVELLER_ID", "BOOKING_ID"])

    discount_tracker = {}
    results = []

    for _, row in df.iterrows():
        # Get total discount so far for this traveller
        total_discount = discount_tracker.get(row["TRAVELLER_ID"], 0)

        # Calculate 10% discount, respecting max 100 per traveller
        discount = row["BOOKING_AMOUNT"] * 0.10
        allowed_discount = max(0, 100 - total_discount)
        discount = min(discount, allowed_discount)

        final_amt = row["BOOKING_AMOUNT"] - discount

        # Update total discount tracker
        discount_tracker[row["TRAVELLER_ID"]] = total_discount + discount

        results.append({
            "TRAVELLER_ID": row["TRAVELLER_ID"],
            "TRAVELLER_NAME": row["TRAVELLER_NAME"],
            "BOOKING_ID": row["BOOKING_ID"],
            "BOOKING_AMOUNT": float(round(row["BOOKING_AMOUNT"], 2)),
            "DISCOUNT": float(round(discount, 2)),
            "FINAL_AMOUNT": float(round(final_amt, 2)),
        })

    return session.create_dataframe(results)
