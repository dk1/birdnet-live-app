# Modo ARU

!!! note "Implementação inicial"
    O modo ARU atualmente cria uma sessão de implantação agendada e recuperável, e acompanha os ciclos de gravação planejados. A gravação de áudio por ciclo e as notificações Android em primeiro plano estão conectadas nesta versão inicial; inferência, clipes somente de detecção e reprodução completa na revisão ainda estão em desenvolvimento.

O modo ARU (Autonomous Recording Unit) é o fluxo de trabalho para implantações acústicas agendadas em local fixo.

## Configuração atual

- **Implantação e áudio**: insira nome da implantação, ID do ARU/estação, observador, local fixo e modo de gravação. A configuração reutiliza o seletor de microfone compartilhado e mostra a prévia do clima quando a busca meteorológica está permitida. A gravação de clipes somente de detecção e os controles de retenção de clipes ficam ocultos até que a inferência agendada esteja conectada de ponta a ponta.
- **Agenda**: escolha duração do ciclo, intervalo de repetição, como a implantação deve terminar e um limite de parada por bateria fraca. Você pode parar manualmente, parar após um número fixo de ciclos ou parar em data e hora fixas. O ciclo de teste opcional de um minuto continua planejado, mas permanece oculto até funcionar de ponta a ponta.
- **Pronto**: revise a agenda e o armazenamento de áudio estimado, depois inicie a implantação.

Ao iniciar, uma sessão `SessionType.aru` é salva imediatamente com metadados da agenda ARU para que o estado dos ciclos possa ser recuperado depois.

As exportações JSON e ZIP incluem metadados da implantação ARU. Se uma versão futura salvar arquivos de gravação por ciclo na sessão, a exportação ZIP agrupa esses arquivos em `aru_cycles/`.

## Implantação ativa

A tela ARU ativa mostra se a implantação está aguardando, gravando ou concluída. O layout agora segue Survey: linha de status compacta, abas superiores para agenda, espectrograma ao vivo e resumo, uma barra de estatísticas e um painel persistente de detecções abaixo. O painel mostra detecções do ciclo atual durante a gravação e detecções recentes da implantação enquanto aguarda. No Android, implantações ativas mostram uma notificação em primeiro plano com ações Parar e Abrir.

No iOS, esta implementação inicial deve ser tratada como um fluxo em primeiro plano até que o áudio agendado e o comportamento em segundo plano sejam validados no iOS.

## Ainda planejado

- Inferência e criação de clipes somente de detecção durante os ciclos de gravação agendados.
- Validação do comportamento em segundo plano no iOS.
- Suporte completo a reprodução e espectrograma no Session Review para gravações ARU segmentadas.
