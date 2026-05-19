PROMPT 1:

Generate a production-grade Python synthetic data generator for PostgreSQL
activity_records table for an EU fleet compliance system.

Requirements:
- minimum 150,000 rows
- at least 50 drivers
- at least 10 weeks of timestamps
- realistic driver activity transitions
- plausible sequences:
  DRIVING -> REST -> DRIVING
  DRIVING -> WORK -> REST
- enforce no overlapping activities
- realistic driving durations
- include deliberate EC 561/2006 violations:
  - >9h daily driving
  - >56h weekly driving
  - insufficient 45 minute breaks
  - excessive continuous driving
- output CSV suitable for COPY INTO PostgreSQL
- deterministic/repeatable generation using random seed
- use Python Faker library
- UTC timestamps only
- ensure duration ranges realistic
- produce around 150k rows total
- include comments explaining generation logic