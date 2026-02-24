# Dictionary Licenses and Attributions

This document contains license information and attributions for the dictionary files used in SwiftSpeak's spell checking and word prediction features.

## Arabic Dictionaries

### ar_symspell.txt (Modern Standard Arabic)
- **Source:** CAMeL Arabic Frequency Lists - MSA (Modern Standard Arabic)
- **Provider:** CAMeL Lab, New York University Abu Dhabi
- **License:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- **URL:** https://github.com/CAMeL-Lab/Camel_Arabic_Frequency_Lists
- **Words:** 100,000 most frequent words from 17.3B token corpus
- **Citation:**
  ```
  Ossama Obeid, Nasser Zalmout, Salam Khalifa, Dima Taji, Mai Oudah, Bashar Alhafni,
  Go Inoue, Fadhl Eryani, Alexander Erdmann, and Nizar Habash. 2020.
  CAMeL Tools: An Open Source Python Toolkit for Arabic Natural Language Processing.
  In Proceedings of LREC 2020, Marseille, France.
  ```

### arz_symspell.txt (Egyptian/Dialectal Arabic)
- **Source:** CAMeL Arabic Frequency Lists - DA (Dialectal Arabic)
- **Provider:** CAMeL Lab, New York University Abu Dhabi
- **License:** [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- **URL:** https://github.com/CAMeL-Lab/Camel_Arabic_Frequency_Lists
- **Words:** 100,000 most frequent words from dialectal Arabic corpus (5.8B tokens)
- **Note:** Includes Egyptian, Gulf, Levantine, and Maghrebi dialects

---

## Polish Dictionaries

### pl_diacritics.txt (Polish ASCII to Diacritics Corrections)
- **Source:** N-grams from National Corpus of Polish (NKJP)
- **Provider:** Institute of Computer Science, Polish Academy of Sciences (IPI PAN)
- **License:** [CC BY](https://creativecommons.org/licenses/by/4.0/)
- **URL:** http://zil.ipipan.waw.pl/NKJPNGrams
- **Words:** 20,000 most frequent words with diacritics, mapped from ASCII variants
- **Description:** Maps Polish words typed without diacritics (e.g., "bedzie") to proper Polish spelling with diacritics (e.g., "będzie")
- **Citation:**
  ```
  Adam Przepiórkowski, Mirosław Bańko, Rafał L. Górski, Barbara Lewandowska-Tomaszczyk (eds.).
  2012. Narodowy Korpus Języka Polskiego [National Corpus of Polish].
  Wydawnictwo Naukowe PWN, Warsaw.
  ```

---

## Other Language Dictionaries

### en_symspell.txt, pl_symspell.txt, es_symspell.txt, fr_symspell.txt, de_symspell.txt, it_symspell.txt, pt_symspell.txt, ru_symspell.txt, ko_symspell.txt, zh_symspell.txt, ja_symspell.txt
- **Source:** Hermit Dave's FrequencyWords (OpenSubtitles 2018)
- **License:** Public Domain / Open Data
- **URL:** https://github.com/hermitdave/FrequencyWords

---

## CC BY-SA 4.0 License Summary

The Arabic dictionary files (ar_symspell.txt, arz_symspell.txt) are licensed under Creative Commons Attribution-ShareAlike 4.0 International.

**You are free to:**
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material for any purpose, including commercially

**Under the following terms:**
- Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made
- ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license

**Full license text:** https://creativecommons.org/licenses/by-sa/4.0/legalcode

---

## Obtaining Dictionary Files

The dictionary files used in this application are derived from various open-source corpora:

**Arabic dictionaries (CC BY-SA 4.0):**
- Source: https://github.com/CAMeL-Lab/Camel_Arabic_Frequency_Lists

**Polish diacritics dictionary (CC BY):**
- Source: http://zil.ipipan.waw.pl/NKJPNGrams

To obtain these files:
1. Clone the SwiftSpeak repository
2. Navigate to `SwiftSpeakKeyboard/Resources/Dictionaries/`
3. Or download directly from the sources above

---

*Last updated: January 2025*
