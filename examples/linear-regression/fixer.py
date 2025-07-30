import csv

fields = []
rows = []

with open('data.csv', 'r') as csvfile:
    csvreader = csv.reader(csvfile)

    fields = next(csvreader)

    for row in csvreader:
        rows.append(row)


with open("data_fixed.csv", 'w') as outfile:
    for row in rows:
        outfile.write(f"{row[1]}, {row[4]}\n")


