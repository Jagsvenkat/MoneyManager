/// Category-dependent extra fields for data entry
/// Each category can define extra fields that appear when selected.
/// Field types: 'text', 'number', 'date', 'select' (with options list), 'boolean'
const Map<String, List<Map<String, dynamic>>> categoryExtraFields = {
  // === Expense Categories ===
  'Fuel': [
    {'key': 'vehicleName', 'label': 'Vehicle Name/Number', 'type': 'text'},
    {'key': 'odometerReading', 'label': 'Odometer (km)', 'type': 'number'},
  ],
  'Food & Dining': [
    {'key': 'mealType', 'label': 'Meal Type', 'type': 'select', 'options': ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Beverages']},
    {'key': 'restaurantOrVendor', 'label': 'Restaurant / Vendor', 'type': 'text'},
  ],
  'Groceries': [
    {'key': 'storeName', 'label': 'Store Name', 'type': 'text'},
    {'key': 'billNumber', 'label': 'Bill Number', 'type': 'text'},
  ],
  'Transport': [
    {'key': 'mode', 'label': 'Mode', 'type': 'select', 'options': ['Bus', 'Train', 'Metro', 'Auto', 'Taxi', 'Flight', 'Own Vehicle']},
    {'key': 'fromLocation', 'label': 'From', 'type': 'text'},
    {'key': 'toLocation', 'label': 'To', 'type': 'text'},
  ],
  'Vehicle Maintenance': [
    {'key': 'vehicleName', 'label': 'Vehicle Name/Number', 'type': 'text'},
    {'key': 'odometerReading', 'label': 'Odometer (km)', 'type': 'number'},
    {'key': 'serviceType', 'label': 'Service Type', 'type': 'select', 'options': ['Regular Service', 'Repair', 'Puncture', 'Battery', 'Tyre Change', 'Insurance', 'Other']},
  ],
  'Bills & Utilities': [
    {'key': 'providerName', 'label': 'Provider Name', 'type': 'text'},
    {'key': 'billNumber', 'label': 'Bill Number', 'type': 'text'},
    {'key': 'dueDate', 'label': 'Due Date', 'type': 'date'},
  ],
  'Rent': [
    {'key': 'propertyName', 'label': 'Property Name', 'type': 'text'},
    {'key': 'rentMonth', 'label': 'Rent Month', 'type': 'text'},
  ],
  'Healthcare': [
    {'key': 'patientName', 'label': 'Patient Name', 'type': 'text'},
    {'key': 'doctorOrHospital', 'label': 'Doctor / Hospital', 'type': 'text'},
    {'key': 'billNumber', 'label': 'Bill / Receipt No.', 'type': 'text'},
  ],
  'Education': [
    {'key': 'institutionName', 'label': 'Institution Name', 'type': 'text'},
    {'key': 'courseOrSubject', 'label': 'Course / Subject', 'type': 'text'},
  ],
  'Entertainment': [
    {'key': 'activity', 'label': 'Activity / Event', 'type': 'text'},
    {'key': 'platformOrVenue', 'label': 'Platform / Venue', 'type': 'text'},
  ],
  'Travel': [
    {'key': 'destination', 'label': 'Destination', 'type': 'text'},
    {'key': 'travelMode', 'label': 'Mode', 'type': 'select', 'options': ['Bus', 'Train', 'Flight', 'Cab', 'Metro', 'Own Vehicle']},
  ],
  'Subscriptions': [
    {'key': 'serviceName', 'label': 'Service Name', 'type': 'text'},
    {'key': 'billingCycle', 'label': 'Billing Cycle', 'type': 'select', 'options': ['Monthly', 'Quarterly', 'Yearly']},
    {'key': 'renewalDate', 'label': 'Renewal Date', 'type': 'date'},
  ],
  'Insurance': [
    {'key': 'policyNumber', 'label': 'Policy Number', 'type': 'text'},
    {'key': 'insurer', 'label': 'Insurer', 'type': 'text'},
    {'key': 'policyType', 'label': 'Policy Type', 'type': 'select', 'options': ['Life', 'Health', 'Vehicle', 'Term', 'Travel']},
    {'key': 'renewalDate', 'label': 'Renewal Date', 'type': 'date'},
  ],
  'Gifts & Donations': [
    {'key': 'recipientName', 'label': 'Recipient Name', 'type': 'text'},
    {'key': 'occasion', 'label': 'Occasion', 'type': 'text'},
  ],
  'Home Maintenance': [
    {'key': 'serviceType', 'label': 'Service Type', 'type': 'select', 'options': ['Repair', 'Cleaning', 'Renovation', 'Pest Control', 'Deep Clean', 'Other']},
    {'key': 'vendorName', 'label': 'Vendor Name', 'type': 'text'},
  ],
  'Personal Care': [
    {'key': 'serviceType', 'label': 'Service', 'type': 'select', 'options': ['Salon', 'Spa', 'Gym', 'Wellness']},
    {'key': 'vendorName', 'label': 'Vendor Name', 'type': 'text'},
  ],
  'Shopping': [
    {'key': 'storeName', 'label': 'Store / Platform', 'type': 'text'},
  ],

  // === Income Categories ===
  'Salary': [
    {'key': 'employer', 'label': 'Employer', 'type': 'text'},
    {'key': 'salaryMonth', 'label': 'Salary Month', 'type': 'text'},
    {'key': 'component', 'label': 'Component', 'type': 'select', 'options': ['Salary', 'Bonus', 'Incentive', 'Reimbursement']},
  ],
  'Freelance': [
    {'key': 'clientName', 'label': 'Client Name', 'type': 'text'},
    {'key': 'projectName', 'label': 'Project Name', 'type': 'text'},
    {'key': 'invoiceNumber', 'label': 'Invoice Number', 'type': 'text'},
    {'key': 'paymentStatus', 'label': 'Payment Status', 'type': 'select', 'options': ['Paid', 'Pending', 'Partial']},
  ],
  'Business': [
    {'key': 'customerName', 'label': 'Customer Name', 'type': 'text'},
    {'key': 'invoiceNumber', 'label': 'Invoice Number', 'type': 'text'},
    {'key': 'businessLine', 'label': 'Business Line', 'type': 'text'},
  ],
  'Investments': [
    {'key': 'instrumentName', 'label': 'Instrument Name', 'type': 'text'},
    {'key': 'incomeType', 'label': 'Income Type', 'type': 'select', 'options': ['Dividend', 'Interest', 'Capital Gain']},
  ],
  'Rental Income': [
    {'key': 'propertyName', 'label': 'Property Name', 'type': 'text'},
    {'key': 'rentMonth', 'label': 'Rent Month', 'type': 'text'},
  ],
  'Refunds': [
    {'key': 'originalExpenseCategory', 'label': 'Original Category', 'type': 'text'},
    {'key': 'refundSource', 'label': 'Refund Source', 'type': 'text'},
  ],

  // === Loan Categories ===
  'Personal Loan': _loanFields,
  'Home Loan': _loanFields,
  'Car Loan': _loanFields,
  'Education Loan': _loanFields,
  'Business Loan': _loanFields,
  'Credit Card': [
    {'key': 'cardName', 'label': 'Card Name', 'type': 'text'},
    {'key': 'statementMonth', 'label': 'Statement Month', 'type': 'text'},
    {'key': 'dueDate', 'label': 'Due Date', 'type': 'date'},
    {'key': 'totalDue', 'label': 'Total Due', 'type': 'number'},
  ],
  'Friend/Family': [
    {'key': 'personName', 'label': 'Person Name', 'type': 'text'},
    {'key': 'direction', 'label': 'Direction', 'type': 'select', 'options': ['Borrowed', 'Lent']},
    {'key': 'expectedReturnDate', 'label': 'Expected Return Date', 'type': 'date'},
  ],

  // === Investment Categories ===
  'Stocks': [
    {'key': 'symbol', 'label': 'Symbol', 'type': 'text'},
    {'key': 'broker', 'label': 'Broker', 'type': 'text'},
    {'key': 'units', 'label': 'Units', 'type': 'number'},
    {'key': 'buyPrice', 'label': 'Buy Price', 'type': 'number'},
  ],
  'Mutual Funds': [
    {'key': 'fundName', 'label': 'Fund Name', 'type': 'text'},
    {'key': 'folioNumber', 'label': 'Folio Number', 'type': 'text'},
    {'key': 'units', 'label': 'Units', 'type': 'number'},
    {'key': 'nav', 'label': 'NAV', 'type': 'number'},
  ],
  'Fixed Deposit': [
    {'key': 'bankName', 'label': 'Bank Name', 'type': 'text'},
    {'key': 'fdNumber', 'label': 'FD Number', 'type': 'text'},
    {'key': 'interestRate', 'label': 'Interest Rate (%)', 'type': 'number'},
    {'key': 'maturityDate', 'label': 'Maturity Date', 'type': 'date'},
  ],
  'Gold': [
    {'key': 'goldType', 'label': 'Gold Type', 'type': 'select', 'options': ['Physical', 'ETF', 'SGB', 'Digital']},
    {'key': 'grams', 'label': 'Grams', 'type': 'number'},
    {'key': 'purchaseRate', 'label': 'Purchase Rate', 'type': 'number'},
  ],
  'Silver': [
    {'key': 'silverType', 'label': 'Silver Type', 'type': 'select', 'options': ['Physical', 'ETF', 'Digital']},
    {'key': 'grams', 'label': 'Grams', 'type': 'number'},
    {'key': 'purchaseRate', 'label': 'Purchase Rate', 'type': 'number'},
  ],
  'Real Estate': [
    {'key': 'propertyName', 'label': 'Property Name', 'type': 'text'},
    {'key': 'location', 'label': 'Location', 'type': 'text'},
    {'key': 'purchaseValue', 'label': 'Purchase Value', 'type': 'number'},
  ],
  'Crypto': [
    {'key': 'coin', 'label': 'Coin', 'type': 'text'},
    {'key': 'exchange', 'label': 'Exchange', 'type': 'text'},
    {'key': 'quantity', 'label': 'Quantity', 'type': 'number'},
    {'key': 'buyPrice', 'label': 'Buy Price', 'type': 'number'},
  ],
  'PPF / EPF': [
    {'key': 'accountNumber', 'label': 'Account Number', 'type': 'text'},
    {'key': 'contributionMonth', 'label': 'Contribution Month', 'type': 'text'},
    {'key': 'employeeContribution', 'label': 'Employee Contribution', 'type': 'number'},
  ],
  'NPS': [
    {'key': 'accountNumber', 'label': 'Account Number', 'type': 'text'},
    {'key': 'contributionMonth', 'label': 'Contribution Month', 'type': 'text'},
    {'key': 'employeeContribution', 'label': 'Employee Contribution', 'type': 'number'},
  ],
  'Bonds': [
    {'key': 'bondType', 'label': 'Bond Type', 'type': 'select', 'options': ['Corporate', 'Government', 'Tax Free']},
    {'key': 'faceValue', 'label': 'Face Value', 'type': 'number'},
    {'key': 'interestRate', 'label': 'Interest Rate (%)', 'type': 'number'},
  ],
  'Other Investment': [
    {'key': 'description', 'label': 'Description', 'type': 'text'},
  ],
};

/// Shared loan fields used by Personal Loan, Home Loan, Car Loan, Education Loan, Business Loan
const List<Map<String, dynamic>> _loanFields = [
  {'key': 'lenderName', 'label': 'Lender Name', 'type': 'text'},
  {'key': 'loanAccountNumber', 'label': 'Loan Account Number', 'type': 'text'},
  {'key': 'principalAmount', 'label': 'Principal Amount', 'type': 'number'},
  {'key': 'interestRate', 'label': 'Interest Rate (%)', 'type': 'number'},
  {'key': 'emiAmount', 'label': 'EMI Amount', 'type': 'number'},
  {'key': 'emiDueDate', 'label': 'EMI Due Date', 'type': 'date'},
];
