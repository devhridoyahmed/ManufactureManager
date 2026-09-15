# Manufacturing Manager

A simple Flutter-based business management app for handmade and small manufacturing businesses.

Manufacturing Manager helps small business owners manage raw materials, recipes, production, finished products, sales, expenses, and profit from one simple application.

The project is being developed with a focus on simplicity, offline-first usage, and practical business bookkeeping.

## Features

### Material Management

* Add and manage raw materials
* Track available material stock
* Record material purchases
* Track material purchase costs
* Set minimum stock alert quantities
* Support different measurement units

### Recipe Management

* Create product recipes
* Add raw materials to recipes
* Add other recipes as components
* Calculate material cost
* Calculate labour cost
* Calculate total recipe cost
* Support nested recipes

### Product Management

* Create products from recipes
* Produce finished products
* Track finished-product stock
* Record maker name
* Record production expenses
* Calculate production cost
* Calculate estimated selling price
* Support customized final selling prices

### Sales Management

* Sell products from available stock
* Record customer information
* Record selling quantity
* Record customized selling price
* Track platform fees
* Track delivery costs
* Track other sale expenses
* Track paid and due amounts
* Track payment status
* Track delivery status
* Calculate sale profit

### Planned Features

* All sales history
* Product-specific sales history
* Dashboard with business summary
* Monthly sales report
* Gross profit report
* Low-stock alerts
* Customer management
* Expense tracking
* Data backup and recovery
* Cloud backup support

## Technology Stack

* Flutter
* Dart
* SQLite
* sqflite
* Android
* Local-first database architecture

## Project Structure

```text
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   └── database/
│       ├── app_database.dart
│       ├── database_migrations.dart
│       └── database_schema.dart
├── repositories/
│   ├── business_repository.dart
│   ├── product_repository.dart
│   ├── recipe_repository.dart
│   └── sale_repository.dart
├── screens/
│   ├── dashboard/
│   ├── materials/
│   ├── products/
│   ├── recipes/
│   └── settings/
├── services/
└── widgets/
```

## Main Navigation

The application uses five main sections:

1. Dashboard
2. Materials
3. Recipes
4. Products
5. Settings

Sales and production features are accessed through the Products section rather than creating unnecessary top-level navigation tabs.

## Getting Started

### Requirements

Install the following:

* Flutter SDK
* Dart SDK
* Android Studio
* Android SDK
* VS Code or another Flutter-compatible editor

### Clone the repository

```bash
git clone https://github.com/YOUR-USERNAME/manufacturing-manager.git
```

### Open the project

```bash
cd manufacturing-manager
```

### Install dependencies

```bash
flutter pub get
```

### Check the project

```bash
flutter analyze
```

### Run the application

```bash
flutter run
```

## Database

The application currently uses a local SQLite database.

The database includes support for:

* Businesses
* Business settings
* Units
* Materials
* Material purchases
* Material stock movements
* Recipes
* Recipe ingredients
* Products
* Product stock movements
* Production records
* Sales
* Sale items

Database migrations are used to update the database structure safely as new features are added.

## Development Status

This project is currently under active development.

### Completed

* Flutter project setup
* Five-section main navigation
* SQLite database setup
* Database migrations
* Business initialization
* Material management foundation
* Recipe management
* Nested recipe support
* Recipe cost calculation
* Product creation through production
* Finished-product stock tracking
* Production history
* Product details
* Basic product sales
* Stock deduction after sale
* Basic sale profit calculation

### In Progress

* Central all-sales history
* Product-specific sales history
* Improved historical cost calculation
* Improved target selling-price preservation
* Dashboard
* Settings and customer management
* Cloud backup

## Project Goals

The goal of Manufacturing Manager is not to become a complicated ERP system.

The main goals are:

* Simple user experience
* Practical small-business bookkeeping
* Offline-first operation
* Reliable stock tracking
* Clear production costing
* Easy sales and profit tracking
* Expandable architecture
* Future cloud backup

## Privacy

Do not commit real customer information, private business records, passwords, API keys, or production database files to this repository.

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.

## Author

Developed as a Flutter business-management project for learning, practical use, and future expansion.
