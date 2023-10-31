import pandas as pd

input_file = 'megamillions.csv'
output_file = 'megamillions_formatted.csv'

df = pd.read_csv(input_file)

df['Draw Date'] = pd.to_datetime(df['Draw Date'], format='%m/%d/%Y').dt.strftime('%Y-%m-%d')

df.to_csv(output_file, index=False)
