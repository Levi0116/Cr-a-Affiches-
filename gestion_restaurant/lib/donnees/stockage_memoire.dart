import 'stockage.dart';

Future<Stockage> ouvrirStockage(String nom) async => StockageMemoire();
