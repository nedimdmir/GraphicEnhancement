// The update manifest signature is the only gate between a download and an
// installed program: a valid signed manifest must be accepted, and any change to
// the payload, the signature or the key must be rejected.
#include "graphicenhancement/base/PortableUpdateManifest.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <iostream>
#include <memory>
#include <openssl/evp.h>

using namespace graphicenhancement::portable;

namespace {
int failures = 0;
void check(bool ok, const char* label) {
    failures += !ok;
    std::cout << (ok ? "PASS " : "FAIL ") << label << '\n';
}

using Key = std::unique_ptr<EVP_PKEY, decltype(&EVP_PKEY_free)>;

Key makeKey() {
    EVP_PKEY* key = nullptr;
    std::unique_ptr<EVP_PKEY_CTX, decltype(&EVP_PKEY_CTX_free)> context(
        EVP_PKEY_CTX_new_id(EVP_PKEY_ED25519, nullptr), EVP_PKEY_CTX_free);
    if (context && EVP_PKEY_keygen_init(context.get()) == 1) EVP_PKEY_keygen(context.get(), &key);
    return Key(key, EVP_PKEY_free);
}

QByteArray publicKey(EVP_PKEY* key) {
    QByteArray raw(32, '\0');
    size_t size = raw.size();
    EVP_PKEY_get_raw_public_key(key, reinterpret_cast<unsigned char*>(raw.data()), &size);
    return raw;
}

QByteArray sign(EVP_PKEY* key, const QByteArray& payload) {
    QByteArray signature(64, '\0');
    size_t size = signature.size();
    std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> context(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    EVP_DigestSignInit(context.get(), nullptr, nullptr, nullptr, key);
    EVP_DigestSign(context.get(), reinterpret_cast<unsigned char*>(signature.data()), &size,
                   reinterpret_cast<const unsigned char*>(payload.constData()), payload.size());
    return signature;
}

QByteArray payload(const QString& version) {
    QJsonObject package{
        {"flavor", "NVIDIA"},
        {"asset", packageAssetName(version, "NVIDIA")},
        {"sha256", QString(64, u'a')},
        {"size", 1000},
        {"expandedSize", 2000},
    };
    QJsonObject root{
        {"schema", 1}, {"product", "GraphicEnhancement-portable"}, {"arch", "windows-x64"},
        {"channel", "stable"}, {"version", version}, {"notes", "test"},
        {"packages", QJsonArray{package}},
    };
    return QJsonDocument(root).toJson(QJsonDocument::Compact);
}

QByteArray envelope(const QByteArray& body, const QByteArray& signature) {
    return QJsonDocument(QJsonObject{
        {"payload", QString::fromLatin1(body.toBase64())},
        {"signature", QString::fromLatin1(signature.toBase64())},
    }).toJson(QJsonDocument::Compact);
}
} // namespace

int main() {
    const auto key = makeKey();
    const auto other = makeKey();
    check(key && other, "Ed25519 test keys generated");
    if (!key || !other) return 1;
    const auto trusted = publicKey(key.get());
    const auto body = payload("9.9.9");
    const auto signature = sign(key.get(), body);

    const auto accepted = readUpdateManifest(envelope(body, signature), "NVIDIA", "1.0.0", {}, trusted);
    check(accepted && accepted->version == "9.9.9" && accepted->archiveBytes == 1000,
          "valid signed manifest is accepted");

    auto tampered = body;
    tampered.replace("\"size\":1000", "\"size\":1001");
    check(tampered != body, "tampered payload differs");
    check(!readUpdateManifest(envelope(tampered, signature), "NVIDIA", "1.0.0", {}, trusted),
          "changed payload with the old signature is rejected");

    auto badSignature = signature;
    badSignature[0] = char(badSignature[0] ^ 1);
    check(!readUpdateManifest(envelope(body, badSignature), "NVIDIA", "1.0.0", {}, trusted),
          "changed signature is rejected");

    check(!readUpdateManifest(envelope(body, signature), "NVIDIA", "1.0.0", {}, publicKey(other.get())),
          "manifest signed by another key is rejected");
    check(!readUpdateManifest(envelope(body, signature), "NVIDIA", "1.0.0", {}, QByteArray()),
          "build without a public key accepts nothing");
    check(!readUpdateManifest(envelope(body, signature), "NVIDIA", "9.9.9", {}, trusted),
          "same or older version is not offered");

    std::cout << "failures=" << failures << '\n';
    return failures ? 1 : 0;
}
