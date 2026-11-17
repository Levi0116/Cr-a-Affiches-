# Adapte voice-audio.json pour la voix gratuite Pico (sigles épelés, nombres en lettres).
import json
d = json.load(open('voice-audio.json', encoding='utf-8'))
rep = [('JBL', 'J B L'), ('JR 470 NC', 'J R quatre cent soixante-dix, N C'), ('Tune 770 NC', 'Tune sept cent soixante-dix, N C'), ('IP68', 'I P soixante-huit'), ('IP67', 'I P soixante-sept'), ('AI Sound Boost', 'A I Sound Boost'), ('Xtreme', 'Extrême'), ('Charge 6', 'Charge six'), ('Flip 7', 'Flip sept'), ('Pulse 5', 'Pulse cinq'), ('Extrême 3', 'Extrême trois'), ('Extrême 4', 'Extrême quatre'), ('Boombox 3', 'Boum box trois'), ('PartyBox Stage 320', 'Partie box Stage trois cent vingt'), ('PartyBox 310', 'Partie box trois cent dix'), ('PartyBox', 'Partie box'), ('Studio 8', 'Studio huit'), ('Studio 2', 'Studio deux'), ('Studio 9', 'Studio neuf'), ('Studio 4', 'Studio quatre'), ('Harman Kardon', 'Harmane Kardone'), ('QuietComfort', 'Couaillette Comfort'), ('HomePod', 'Home Pod'), ('francs CFA', 'francs C F A'), ('XXL', 'X X L'), ('Riviera 2', 'Riviera deux'), ('Auracast', 'Aura caste'), ('Pure Bass', 'Pioure Basse'), ('Bose', 'Bôze'), ('USB-C', 'U S B C'), ('powerbank', 'pauweur banque')]
for k, v in d.items():
    for a, b in rep: v = v.replace(a, b)
    d[k] = v
json.dump(d, open('voice-audio-pico.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
