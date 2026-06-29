#!/usr/bin/env python3
"""
Migration Script - Import expenses from CSV to Money Manager format

Converts CSV files from common formats (Mint, YNAB, etc.) to Money Manager's
encrypted envelope format.

Usage:
    python migrate_from_csv.py --input expenses.csv --output converted.json
    
CSV Format Expected:
    Date,Category,Amount,Merchant,Notes,PaymentMethod
    2024-01-15,Food,25.50,Coffee Shop,Morning coffee,Card
"""

import csv
import json
import argparse
from datetime import datetime
import uuid
import sys
from typing import List, Dict, Any


class CsvMigrator:
    """Migrate CSV files to Money Manager format"""
    
    # Column name mappings for different CSV formats
    COLUMN_MAPPINGS = {
        'mint': {
            'date': ['Transaction Date', 'Date'],
            'amount': ['Amount', 'Value'],
            'category': ['Category', 'Type'],
            'merchant': ['Merchant', 'Description', 'Name'],
            'notes': ['Notes', 'Memo'],
            'payment_method': ['Payment Method', 'Account']
        },
        'ynab': {
            'date': ['Date'],
            'amount': ['Amount'],
            'category': ['Category'],
            'merchant': ['Payee'],
            'notes': ['Memo'],
            'payment_method': ['Account']
        },
        'generic': {
            'date': ['Date', 'DateTime', 'TransactionDate'],
            'amount': ['Amount', 'Value', 'Value'],
            'category': ['Category', 'Type'],
            'merchant': ['Merchant', 'Description', 'Payee'],
            'notes': ['Notes', 'Memo', 'Description'],
            'payment_method': ['Method', 'Payment Method', 'Account']
        }
    }

    def __init__(self, format_type: str = 'generic'):
        self.format_type = format_type
        self.mappings = self.COLUMN_MAPPINGS.get(format_type, self.COLUMN_MAPPINGS['generic'])
        self.device_id = str(uuid.uuid4())
        self.user_id = 'migrated_user'

    def _find_column(self, headers: List[str], field_names: List[str]) -> int:
        """Find column index by matching against multiple possible names"""
        headers_lower = [h.lower() for h in headers]
        for field in field_names:
            for idx, header in enumerate(headers_lower):
                if field.lower() in header.lower():
                    return idx
        return -1

    def _parse_amount(self, value: str) -> float:
        """Parse amount from various formats"""
        try:
            # Remove currency symbols and whitespace
            cleaned = value.replace('$', '').replace('€', '').replace('£', '').strip()
            # Handle parentheses for negative amounts
            if cleaned.startswith('(') and cleaned.endswith(')'):
                return -float(cleaned[1:-1])
            return float(cleaned)
        except ValueError:
            print(f"Warning: Could not parse amount: {value}", file=sys.stderr)
            return 0.0

    def _parse_date(self, value: str) -> str:
        """Parse date from various formats"""
        formats = [
            '%Y-%m-%d',
            '%m/%d/%Y',
            '%d/%m/%Y',
            '%Y/%m/%d',
            '%B %d, %Y',
            '%b %d, %Y',
        ]
        
        for fmt in formats:
            try:
                dt = datetime.strptime(value.strip(), fmt)
                return dt.isoformat()
            except ValueError:
                continue
        
        print(f"Warning: Could not parse date: {value}, using current date", file=sys.stderr)
        return datetime.now().isoformat()

    def migrate(self, csv_file: str) -> List[Dict[str, Any]]:
        """Convert CSV to Money Manager format"""
        expenses = []
        
        try:
            with open(csv_file, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                headers = next(reader)
                
                # Find column indices
                date_idx = self._find_column(headers, self.mappings['date'])
                amount_idx = self._find_column(headers, self.mappings['amount'])
                category_idx = self._find_column(headers, self.mappings['category'])
                merchant_idx = self._find_column(headers, self.mappings['merchant'])
                notes_idx = self._find_column(headers, self.mappings['notes'])
                payment_method_idx = self._find_column(headers, self.mappings['payment_method'])
                
                # Validate required columns
                if date_idx == -1 or amount_idx == -1:
                    print("Error: Could not find Date and Amount columns", file=sys.stderr)
                    return []
                
                print(f"Parsing CSV with columns: Date={headers[date_idx]}, Amount={headers[amount_idx]}")
                print(f"Found {len(headers)} columns", file=sys.stderr)
                
                # Parse rows
                for row_num, row in enumerate(reader, start=2):
                    if len(row) < len(headers):
                        print(f"Warning: Row {row_num} has fewer columns than header", file=sys.stderr)
                        continue
                    
                    try:
                        amount = self._parse_amount(row[amount_idx])
                        
                        expense = {
                            'id': str(uuid.uuid4()),
                            'amount': amount,
                            'currency': 'USD',  # Default, could be configured
                            'dateTime': self._parse_date(row[date_idx]),
                            'category': row[category_idx].strip() if category_idx >= 0 else 'Uncategorized',
                            'merchant': row[merchant_idx].strip() if merchant_idx >= 0 else None,
                            'notes': row[notes_idx].strip() if notes_idx >= 0 else None,
                            'paymentMethod': row[payment_method_idx].strip() if payment_method_idx >= 0 else None,
                            'tags': [],
                            'createdAt': datetime.now().isoformat(),
                            'updatedAt': datetime.now().isoformat(),
                            'deviceId': self.device_id,
                            'userId': self.user_id,
                            'syncStatus': 'pending',
                            'version': '1.0',
                            'isReconciled': False,
                        }
                        
                        expenses.append(expense)
                    except Exception as e:
                        print(f"Warning: Could not parse row {row_num}: {e}", file=sys.stderr)
                        continue
        except FileNotFoundError:
            print(f"Error: File not found: {csv_file}", file=sys.stderr)
            return []
        except Exception as e:
            print(f"Error reading CSV: {e}", file=sys.stderr)
            return []
        
        return expenses

    def export_json(self, expenses: List[Dict[str, Any]], output_file: str) -> bool:
        """Export expenses to JSON format"""
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump({
                    'version': '1.0',
                    'deviceId': self.device_id,
                    'userId': self.user_id,
                    'exportedAt': datetime.now().isoformat(),
                    'recordCount': len(expenses),
                    'expenses': expenses,
                }, f, indent=2)
            print(f"✓ Exported {len(expenses)} expenses to {output_file}")
            return True
        except Exception as e:
            print(f"Error writing output: {e}", file=sys.stderr)
            return False


def main():
    parser = argparse.ArgumentParser(
        description='Migrate expenses from CSV to Money Manager format'
    )
    parser.add_argument('--input', required=True, help='Input CSV file')
    parser.add_argument('--output', required=True, help='Output JSON file')
    parser.add_argument('--format', choices=['mint', 'ynab', 'generic'], default='generic',
                       help='CSV format type (default: generic)')
    parser.add_argument('--validate', action='store_true',
                       help='Validate output without writing')
    
    args = parser.parse_args()
    
    print(f"🔄 Migrating from {args.input}...")
    print(f"   Format: {args.format}")
    
    migrator = CsvMigrator(format_type=args.format)
    expenses = migrator.migrate(args.input)
    
    if not expenses:
        print("❌ No expenses migrated", file=sys.stderr)
        return 1
    
    print(f"✓ Parsed {len(expenses)} expenses")
    
    # Validate
    valid_count = 0
    for exp in expenses:
        if exp['amount'] > 0 and exp['dateTime']:
            valid_count += 1
    
    print(f"✓ {valid_count}/{len(expenses)} expenses are valid")
    
    if args.validate:
        print("✓ Validation complete (no output written)")
        return 0
    
    # Export
    if migrator.export_json(expenses, args.output):
        print("\n✅ Migration complete!")
        print(f"   Next step: In app, Settings → Import → Select {args.output}")
        return 0
    else:
        return 1


if __name__ == '__main__':
    sys.exit(main())
