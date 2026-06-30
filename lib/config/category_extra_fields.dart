/// Category-dependent extra fields for data entry
/// Each category can define extra fields that appear when selected.
/// Field types: 'text', 'number', 'select' (with options list)
const Map<String, List<Map<String, dynamic>>> categoryExtraFields = {
  'Fuel': [
    {'key': 'odometer', 'label': 'Odometer (km)', 'type': 'number'},
    {'key': 'fuelStation', 'label': 'Fuel Station', 'type': 'text'},
  ],
  'Vehicle Maintenance': [
    {'key': 'maintType', 'label': 'Maintenance Type', 'type': 'select', 'options': ['Regular Service', 'Repair', 'Puncture', 'Battery', 'Tyre Change', 'Insurance', 'Other']},
    {'key': 'vehicleNo', 'label': 'Vehicle No.', 'type': 'text'},
  ],
  'Food & Dining': [
    {'key': 'mealType', 'label': 'Meal Type', 'type': 'select', 'options': ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Beverages']},
  ],
  'Healthcare': [
    {'key': 'billNo', 'label': 'Bill / Receipt No.', 'type': 'text'},
    {'key': 'healthType', 'label': 'Type', 'type': 'select', 'options': ['Doctor Visit', 'Medicine', 'Lab Test', 'Surgery', 'Insurance Claim']},
  ],
  'Shopping': [
    {'key': 'storeName', 'label': 'Store / Platform', 'type': 'text'},
  ],
  'Entertainment': [
    {'key': 'activity', 'label': 'Activity / Event', 'type': 'text'},
  ],
  'Travel': [
    {'key': 'destination', 'label': 'Destination', 'type': 'text'},
    {'key': 'travelMode', 'label': 'Mode', 'type': 'select', 'options': ['Bus', 'Train', 'Flight', 'Cab', 'Metro', 'Own Vehicle']},
  ],
  'Education': [
    {'key': 'courseOrSubject', 'label': 'Course / Subject', 'type': 'text'},
  ],
  'Home Maintenance': [
    {'key': 'maintType', 'label': 'Type', 'type': 'select', 'options': ['Repair', 'Cleaning', 'Renovation', 'Pest Control', 'Deep Clean', 'Other']},
  ],
  'Personal Care': [
    {'key': 'serviceType', 'label': 'Service', 'type': 'select', 'options': ['Salon', 'Spa', 'Gym', 'Wellness', 'Spa']},
  ],
  'Rent': [
    {'key': 'rentPeriod', 'label': 'Period', 'type': 'select', 'options': ['Current Month', 'Advance', 'Deposit', 'Maintenance']},
  ],
  'Electricity': [
    {'key': 'meterReading', 'label': 'Meter Reading', 'type': 'number'},
  ],
  'Salary': [
    {'key': 'employer', 'label': 'Employer', 'type': 'text'},
  ],
  'Freelance': [
    {'key': 'clientName', 'label': 'Client / Project', 'type': 'text'},
  ],
};
