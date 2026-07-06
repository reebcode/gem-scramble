import 'package:flutter_test/flutter_test.dart';
import 'package:gem_scramble/core/api_client.dart';
import 'package:gem_scramble/core/result.dart';
import 'package:gem_scramble/models/transaction.dart';
import 'package:gem_scramble/models/user.dart';
import 'package:gem_scramble/providers/wallet_provider.dart';
import 'package:gem_scramble/repositories/wallet_repository.dart';

User _user({int gems = 100, int bonusGems = 10}) => User(
      id: 'u1',
      username: 'tester',
      gems: gems,
      bonusGems: bonusGems,
      createdAt: DateTime.utc(2026),
      lastActiveAt: DateTime.utc(2026),
    );

class FakeWalletRepository extends WalletRepository {
  FakeWalletRepository() : super(ApiClient());

  Result<User> userResult = Success(_user());
  Result<List<Transaction>> transactionsResult = const Success([]);
  bool cacheCleared = false;

  @override
  Future<Result<User>> fetchCurrentUser() async => userResult;

  @override
  Future<Result<List<Transaction>>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async =>
      transactionsResult;

  @override
  Future<User?> loadCachedUser() async => null;

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }
}

void main() {
  group('WalletProvider', () {
    late FakeWalletRepository repo;
    late WalletProvider provider;

    setUp(() {
      repo = FakeWalletRepository();
      provider = WalletProvider(repo);
    });

    test('refreshUser exposes balances on success', () async {
      repo.userResult = Success(_user(gems: 250, bonusGems: 50));

      await provider.refreshUser();

      expect(provider.user, isNotNull);
      expect(provider.gemBalance, 250);
      expect(provider.bonusGemBalance, 50);
      expect(provider.totalGemBalance, 300);
      expect(provider.userError, isNull);
      expect(provider.isLoadingUser, isFalse);
    });

    test('refreshUser keeps last-known user on failure', () async {
      await provider.refreshUser();
      expect(provider.user, isNotNull);

      repo.userResult = const Failure('server down');
      await provider.refreshUser();

      expect(provider.user, isNotNull,
          reason: 'stale data should survive a failed refresh');
      expect(provider.userError, 'server down');
    });

    test('refreshTransactions surfaces errors', () async {
      repo.transactionsResult = const Failure('nope');

      await provider.refreshTransactions();

      expect(provider.transactions, isEmpty);
      expect(provider.transactionsError, 'nope');
    });

    test('clear wipes state and cache', () async {
      await provider.refreshUser();
      expect(provider.user, isNotNull);

      await provider.clear();

      expect(provider.user, isNull);
      expect(provider.transactions, isEmpty);
      expect(provider.gemBalance, 0);
      expect(repo.cacheCleared, isTrue);
    });

    test('notifies listeners on refresh', () async {
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.refreshUser();

      expect(notifications, greaterThanOrEqualTo(2),
          reason: 'loading start and completion should both notify');
    });
  });
}
