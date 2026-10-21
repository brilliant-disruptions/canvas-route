import '../models/product.dart';
import '../supabase_client.dart';

class ProductRepository {
  Future<List<Product>> canonical() async {
    final rows = await sb.from('products').select().eq('is_canonical', true).order('release_date', ascending: false);
    return rows.map(Product.fromRow).toList();
  }

  Future<List<Product>> search(String q) async {
    final rows = await sb.from('products').select().ilike('display_name', '%$q%').limit(30);
    return rows.map(Product.fromRow).toList();
  }

  Future<Product> addFreeText(String name, String userId) async {
    final row = await sb
        .from('products')
        .insert({
          'game': 'other',
          'set_name': name,
          'sku_type': 'other',
          'display_name': name,
          'is_canonical': false,
          'created_by': userId,
        })
        .select()
        .single();
    return Product.fromRow(row);
  }

  Future<Set<String>> follows(String userId) async {
    final rows = await sb.from('follows').select('product_id').eq('user_id', userId);
    return rows.map((r) => r['product_id'] as String).toSet();
  }

  Future<void> follow(String userId, String productId) =>
      sb.from('follows').upsert({'user_id': userId, 'product_id': productId});

  Future<void> unfollow(String userId, String productId) =>
      sb.from('follows').delete().eq('user_id', userId).eq('product_id', productId);

  Future<List<Product>> nonCanonical() async {
    final rows = await sb.from('products').select().eq('is_canonical', false).order('created_at');
    return rows.map(Product.fromRow).toList();
  }

  Future<void> merge(String fromId, String intoId) =>
      sb.from('products').update({'canonical_id': intoId}).eq('id', fromId);
}
