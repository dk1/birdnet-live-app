# Política de Privacidade

**Última atualização:** Julho 2026

O BirdNET Live respeita sua privacidade. Este documento explica como o aplicativo lida com seus dados.

## Processamento no Dispositivo

Toda a análise de áudio e a identificação de espécies de aves acontecem **inteiramente no seu dispositivo**. O app usa dois modelos de redes neurais que rodam localmente:

- **Classificador de áudio BirdNET+** — analisa o áudio do microfone para identificar espécies de aves.
- **Geomodelo BirdNET** — prevê quais espécies são prováveis na sua localização e época do ano.

Nenhum dado de áudio é jamais transmitido para servidores externos.

## Coleta de Dados

O BirdNET Live **não** coleta, transmite nem compartilha nenhum dado pessoal. Não há análise, rastreamento nem telemetria.

### Dados armazenados localmente no seu dispositivo:

| Tipo de dado | Propósito | Armazenamento |
|--------------|-----------|---------------|
| Gravações de áudio | Identificação de aves, reprodução, exportação | Arquivos locais |
| Resultados de detecção | Espécies, confiança, marcas de tempo | Arquivos JSON de sessão locais |
| Coordenadas GPS | Geotag de detecções, trilhas do Survey, previsões do geomodelo | Arquivos JSON de sessão locais |
| Metadados de sessão | Histórico de sessões, revisão, exportação | Arquivos JSON de sessão locais |
| Snapshot do clima (opcional) | Captura única de temperatura, precipitação, vento, nuvens e código do tempo por sessão quando **Permitir consulta de clima** está ativo | Arquivos JSON de sessão locais |
| Configurações do app | Preferências do usuário | SharedPreferences |

### Dados offline integrados

Imagens, descrições e dados taxonômicos das espécies são **integrados ao app** e carregados de recursos locais. Nenhuma requisição de rede é feita para obter informações sobre espécies.

## Serviços Externos

O aplicativo pode acessar os recursos externos abaixo. Cada um é controlado por um interruptor independente em **Configurações → Privacidade**, e **todos os três estão desligados por padrão** em uma instalação nova. Nada sai do seu dispositivo até você autorizar.

| Recurso | Propósito | Controlado por | Enviado por requisição |
|---------|-----------|----------------|------------------------|
| Tiles de mapa (OpenStreetMap) | Mapa base para seletor de localização, mapa ao vivo do Survey e mapa da sessão | **Configurações → Privacidade → Permitir tiles de mapa** | Coordenadas do tile `(z, x, y)` e user-agent BirdNET Live — sem PII |
| Geocodificação reversa (OpenStreetMap Nominatim) | Resolver coordenadas GPS num nome de lugar legível (ex. “Lisboa, Portugal”) para exibição da sessão | **Configurações → Privacidade → Permitir busca de nome de lugar** | A latitude/longitude da sessão, mais o user-agent BirdNET Live |
| Snapshot do clima (Open-Meteo) | Captura única das condições locais (temperatura, precipitação, vento, nuvens, código WMO) nas coordenadas de gravação e hora de fim | **Configurações → Privacidade → Permitir consulta de clima** | A latitude/longitude da sessão e o timestamp de fim, mais o user-agent BirdNET Live |

As requisições de tiles de mapa são requisições HTTPS GET padrão para `tile.openstreetmap.org` com o user-agent BirdNET Live. Apenas as coordenadas do tile são enviadas — nenhuma informação de identificação pessoal.

As requisições de geocodificação reversa enviam a latitude e a longitude da sessão para `nominatim.openstreetmap.org` via HTTPS, junto com o user-agent BirdNET Live conforme exige a [Política de uso do Nominatim](https://operations.osmfoundation.org/policies/nominatim/). O nome de lugar resolvido é armazenado localmente com a sessão, de modo que uma sessão só é geocodificada uma vez. Nenhuma requisição é feita se a sessão não tiver coordenadas GPS ou o dispositivo estiver offline.

As requisições de clima enviam a latitude/longitude da sessão e o timestamp de fim para `api.open-meteo.com` via HTTPS, junto com o user-agent BirdNET Live. O [Open-Meteo](https://open-meteo.com/) é um serviço gratuito e não exige conta nem chave de API. O snapshot de clima retornado é armazenado localmente com a sessão e também é gravado na exportação JSON, no bloco `metadata.json` da sessão e no relatório HTML.

**Retenção:** nenhum dos serviços de terceiros acima é contatado para *enviar* ou *armazenar* dados do usuário. Os valores retornados (nome do lugar, snapshot de clima) vivem apenas no registro local da sessão no seu dispositivo, e só viajam para os arquivos de exportação que você produzir explicitamente.

**Revogação:** você pode desativar qualquer um dos três serviços a qualquer momento em **Configurações → Privacidade**. Os nomes de lugar e snapshots de clima já armazenados localmente permanecem anexados às sessões onde foram capturados; exclua essas sessões na Biblioteca de Sessões ou use **Configurações → Zona de Perigo → Limpar todos os dados** para remover esses dados históricos.

**Nenhuma outra requisição de rede é feita.** O app funciona totalmente offline.

## Links externos

O BirdNET Live inclui links para sites de terceiros que você pode optar por abrir — por exemplo, as páginas de **eBird**, **iNaturalist** e **Wikipédia** de uma espécie e o link de áudio *«Ouça esta espécie no eBird»* na visualização da espécie, além de links para o site do projeto BirdNET, o código-fonte, o guia do usuário e a página de doações na tela **Sobre**. Os links que saem do app são marcados com um ícone de link externo (↗) para que você os reconheça antes de tocar.

Enquanto um link é apenas exibido, nada é enviado, e nenhum link externo é aberto automaticamente: o navegador abre somente quando você toca nele. O link então abre no navegador padrão do seu dispositivo e você sai do BirdNET Live. O destino é operado por terceiros e regido pela **própria** política de privacidade e pelos próprios termos, não por esta. Esses sites podem coletar de forma independente informações sobre sua visita — por exemplo, seu endereço IP, dados do dispositivo ou navegador e como você interage com as páginas — e definir seus próprios cookies. Não controlamos nem nos responsabilizamos pelo conteúdo ou pelas práticas de dados de sites externos; recomendamos revisar a política de privacidade de cada site.

## GPS e Localização

O app usa a localização GPS para:

- **Filtragem de espécies** — prever quais espécies são prováveis na sua localização.
- **Modo Survey** — registrar trilhas GPS e geotag de detecções ao longo de um transecto.
- **Modo Point Count** — marcar o local da observação.

Os dados GPS são armazenados localmente e incluídos nas exportações apenas quando você compartilha ou exporta explicitamente uma sessão. O acesso à localização requer sua permissão e pode ser revogado a qualquer momento nas configurações do sistema.

## Exportação de Dados

Você pode exportar os dados de sessão em vários formatos (Raven Selection Tables, CSV, JSON, GPX) e marcar qualquer combinação de formatos ao mesmo tempo em **Configurações → Exportação → Formatos**; os formatos selecionados são agrupados em um único ZIP junto com os clipes de áudio e o relatório HTML autônomo opcional. As exportações são geradas localmente e compartilhadas pela folha de compartilhamento do sistema. O app não envia dados de exportação para nenhum servidor.

## Exclusão de Dados

Sessões individuais e suas gravações podem ser excluídas na Biblioteca de Sessões. Para apagar de dentro do app as sessões locais, gravações, notas de voz, listas de espécies personalizadas, preferências e caches do BirdNET Live, use **Configurações → Zona de Perigo → Limpar todos os dados**. Você também pode limpar o armazenamento do app BirdNET Live nas configurações do seu sistema operacional ou desinstalar o app.

## Contato

Para dúvidas sobre privacidade: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
