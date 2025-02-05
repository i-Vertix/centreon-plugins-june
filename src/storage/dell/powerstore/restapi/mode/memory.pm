#
# Copyright 2023 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package storage::dell::powerstore::restapi::mode::memory;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_output {
    my ($self, %options) = @_;

    return sprintf(
        'memory total: %s %s used: %s %s (%.2f%%) free: %s %s (%.2f%%)',
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{total}),
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{used}),
        $self->{result_values}->{prct_used},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{free}),
        $self->{result_values}->{prct_free}
    );
}

sub prefix_appliance_output {
    my ($self, %options) = @_;

    return "Appliance '" . $options{instance} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'memory', type => 1, cb_prefix_output => 'prefix_appliance_output', message_multiple => 'All appliances memory usage are ok' },
    ];

    $self->{maps_counters}->{memory} = [
        { label => 'usage', nlabel => 'memory.usage.bytes', set => {
                key_values => [ { name => 'used' }, { name => 'free' }, { name => 'prct_used' }, { name => 'prct_free' }, { name => 'total' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'usage-free', display_ok => 0, nlabel => 'memory.free.bytes', set => {
                key_values => [ { name => 'free' }, { name => 'used' }, { name => 'prct_used' }, { name => 'prct_free' }, { name => 'total' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'usage-prct', display_ok => 0, nlabel => 'memory.usage.percentage', set => {
                key_values => [ { name => 'prct_used' }, { name => 'used' }, { name => 'free' }, { name => 'prct_free' }, { name => 'total' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-appliance-id:s' => { name => 'filter_appliance_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $appliances = $options{custom}->get_space_metrics_by_appliance();

    $self->{memory} = {};
    foreach my $appliance_id (keys %$appliances) {
        next if (defined($self->{option_results}->{filter_appliance_id}) && $self->{option_results}->{filter_appliance_id} ne '' &&
            $appliance_id !~ /$self->{option_results}->{filter_appliance_id}/);

        my $total = defined($appliances->{$appliance_id}->[-1]->{last_physical_total}) ? $appliances->{$appliance_id}->[-1]->{last_physical_total} : $appliances->{$appliance_id}->[-1]->{physical_total};
        my $used =  defined($appliances->{$appliance_id}->[-1]->{last_physical_used}) ? $appliances->{$appliance_id}->[-1]->{last_physical_used} : $appliances->{$appliance_id}->[-1]->{physical_used};
        my $free = $total - $used;
        $self->{memory}->{ $appliance_id } = {
            total => $total,
            used => $used,
            free => $free,
            prct_used => $used * 100 / $total,
            prct_free => $free * 100 / $total
        };
    }
}

1;

__END__

=head1 MODE

Check appliances memory usage.

=over 8

=item B<--filter-appliance-id>

Filter appliance ID.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'usage' (B), 'usage-free' (B), 'usage-prct' (%).

=back

=cut
