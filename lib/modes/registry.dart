import '../data/models/app_mode.dart';
import 'card_drops.dart';
import 'field_sales.dart';
import 'mode_pack.dart';
import 'yard_sales.dart';

const modePacks = <AppMode, ModePack>{
  AppMode.fieldSales: fieldSalesPack,
  AppMode.yardSales: yardSalesPack,
  AppMode.cardDrops: cardDropsPack,
};

ModePack packFor(AppMode mode) => modePacks[mode]!;
