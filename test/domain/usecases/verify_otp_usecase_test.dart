import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/domain/usecases/auth/verify_otp_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late VerifyOtpUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = VerifyOtpUseCase(mockRepository);
  });

  group('VerifyOtpUseCase', () {
    test('يرفض رمزاً أقصر من 6 أرقام قبل استدعاء المستودع', () async {
      const params = VerifyOtpParams(
        phoneNumber: '+967771234567',
        otp: '123',
      );

      final result = await useCase(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('Should fail'),
      );
      verifyNever(
        () => mockRepository.verifyOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otp: any(named: 'otp'),
        ),
      );
    });

    test('يستدعي المستودع برمز صالح', () async {
      const params = VerifyOtpParams(
        phoneNumber: '+967771234567',
        otp: '123456',
      );

      when(
        () => mockRepository.verifyOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer((_) async => (true, null));

      final result = await useCase(params);

      expect(result.isRight(), isTrue);
      verify(
        () => mockRepository.verifyOtp(
          phoneNumber: '+967771234567',
          otp: '123456',
        ),
      ).called(1);
    });

    test('يمرر فشل المستودع كما هو', () async {
      const params = VerifyOtpParams(
        phoneNumber: '+967771234567',
        otp: '000000',
      );

      when(
        () => mockRepository.verifyOtp(
          phoneNumber: any(named: 'phoneNumber'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer(
        (_) async => (false, const OtpInvalidFailure()),
      );

      final result = await useCase(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<OtpInvalidFailure>()),
        (_) => fail('Should fail'),
      );
    });
  });
}
