#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use JSON::PP qw(decode_json);

use Business::Stripe::Webhook;

plan tests => 11;

my $payload = '{"id":"evt_123","object":"event","type":"invoice.paid"}';

sub capture_reply {
    my ($webhook, @args) = @_;
    my $output = '';
    open my $fh, '>', \$output or die "Unable to capture STDOUT: $!";
    local *STDOUT = $fh;
    $webhook->reply(@args);
    return $output;
}

my $handled = 0;
my $webhook = Business::Stripe::Webhook->new(
    payload       => $payload,
    'invoice-paid' => sub { $handled = 1; },
);

$webhook->process();

ok( $handled, 'callback ran' );

my $output = capture_reply($webhook, status => 'ok');
ok( $output =~ /\AContent-type: application\/json\n\n/s, 'reply includes content-type header' );

my (undef, $body) = split(/\n\n/, $output, 2);
my $data = decode_json($body);

is( $data->{'status'}, 'ok', 'status overridden via reply args' );
is_deeply( $data->{'sent_to'}, ['invoice-paid'], 'sent_to includes handler' );
is( $data->{'sent_to_all'}, 'false', 'sent_to_all defaults to false' );
like( $data->{'timestamp'}, qr/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\z/, 'timestamp present' );

my $webhook_nohandler = Business::Stripe::Webhook->new(
    payload => $payload,
);

$webhook_nohandler->process();

my $output_nohandler = capture_reply($webhook_nohandler);
ok( $output_nohandler =~ /\AContent-type: application\/json\n\n/s, 'reply includes content-type header without args' );

my (undef, $body_nohandler) = split(/\n\n/, $output_nohandler, 2);
my $data_nohandler = decode_json($body_nohandler);

is( $data_nohandler->{'status'}, 'noaction', 'default status is noaction' );
is_deeply( $data_nohandler->{'sent_to'}, [], 'sent_to empty when no handler' );
is( $data_nohandler->{'sent_to_all'}, 'false', 'sent_to_all remains false' );
like( $data_nohandler->{'timestamp'}, qr/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\z/, 'timestamp present without args' );
