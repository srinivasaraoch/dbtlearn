from datetime import datetime
from dateutil import parser
from sklearn.preprocessing import LabelEncoder

def model(dbt, session):
    dbt.config(
        packages=['scikit-learn'], 
        materialized='table'
    )

    # Load TRAVELLERS table into pandas DataFrame
    df = dbt.source("training", "travellers").to_pandas()

    # Parse dates in various formats with dateutil and calculate age from DOB
    def calculate_age(dob_string):
        dob = parser.parse(dob_string)
        age = datetime.today().year - dob.year
        return age

    df['AGE'] = df['DOB'].apply(calculate_age)

    # Encode categorical columns to numeric
    df['GENDER_ENCODED'] = LabelEncoder().fit_transform(df['GENDER'].astype(str))
    df['CITY_ENCODED'] = LabelEncoder().fit_transform(df['CITY'].astype(str))

    # Select final columns for output
    result_df = df[['TRAVELLER_ID', 'AGE', 'GENDER_ENCODED', 'CITY_ENCODED']]

    # Return Snowpark DataFrame
    return session.create_dataframe(result_df)
