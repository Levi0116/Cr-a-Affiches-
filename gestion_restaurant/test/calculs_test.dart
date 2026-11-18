import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_restaurant/core/calculs.dart';
import 'package:gestion_restaurant/core/format.dart';
import 'package:gestion_restaurant/core/pin.dart';

void main() {
  const lignes = [LigneCalcul(3, 700), LigneCalcul(1, 4000), LigneCalcul(2, 500, annulee: true)];

  test('sous-total ignore les lignes annulées', () {
    expect(sousTotal(lignes), 6100);
  });

  test('remise en montant et en pourcentage, arrondie et plafonnée', () {
    const rm = Remise(type: TypeRemise.montant, valeur: 100, motif: 'm', validePar: 'a');
    const rp = Remise(type: TypeRemise.pourcentage, valeur: 15, motif: 'm', validePar: 'a');
    const trop = Remise(type: TypeRemise.montant, valeur: 99999, motif: 'm', validePar: 'a');
    expect(calculerTotaux(lignes, remise: rm).total, 6000);
    expect(calculerTotaux(lignes, remise: rp).remise, 915);
    expect(calculerTotaux(lignes, remise: rp).total, 5185);
    expect(calculerTotaux(lignes, remise: trop).total, 0);
  });

  test('TVA incluse dans les prix TTC', () {
    expect(tvaIncluse(11800, 18), 1800);
    expect(calculerTotaux(lignes).tva, 0);
    expect(calculerTotaux(lignes, tauxTva: 18).tva, 931);
  });

  test('monnaie à rendre', () {
    expect(monnaieARendre(10000, 6100), 3900);
    expect(monnaieARendre(6100, 6100), 0);
    expect(() => monnaieARendre(5000, 6100), throwsArgumentError);
  });

  test('parts égales : la somme fait exactement le total', () {
    expect(partsEgales(10000, 3), [3334, 3333, 3333]);
    expect(partsEgales(10000, 3).reduce((a, b) => a + b), 10000);
    expect(partsEgales(700, 1), [700]);
  });

  test('conversion des casiers', () {
    expect(casiersEnUnites(casiers: 2, unitesParCasier: 12, unitesIsolees: 5), 29);
    expect(casiersEnUnites(casiers: 1, unitesParCasier: 24), 24);
    expect(() => casiersEnUnites(casiers: -1, unitesParCasier: 12), throwsArgumentError);
  });

  test('coût moyen pondéré', () {
    expect(nouveauCoutMoyen(stockActuel: 10, coutMoyenActuel: 500, quantiteEntree: 10, prixAchatUnitaire: 600), 550);
    expect(nouveauCoutMoyen(stockActuel: -2, coutMoyenActuel: 500, quantiteEntree: 12, prixAchatUnitaire: 520), 520);
  });

  test('numérotation continue et format', () {
    expect(numeroFacture(2026, 123), 'FAC-2026-000123');
    expect(numeroAvoir(2026, 7), 'AV-2026-000007');
  });

  test('PIN haché, salé par employé', () {
    final a = hacherPin(idRestaurant: 'r', idEmploye: 'e1', pin: '1234');
    final b = hacherPin(idRestaurant: 'r', idEmploye: 'e2', pin: '1234');
    expect(a, isNot(contains('1234')));
    expect(a, isNot(b));
    expect(pinValide('0123'), isTrue);
    expect(pinValide('123'), isFalse);
    expect(pinValide('12a4'), isFalse);
  });

  test('format FCFA', () {
    expect(fcfa(12500), '12 500 F');
  });
}
