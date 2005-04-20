package Gtk2::Ex::ICal::Recur::Selection;

our $VERSION = '0.03';

use strict;
use warnings;

sub new {
	my ($class, $column_names, $data_attributes) = @_;
	my $self  = {};
	bless ($self, $class);
	return $self;
}

sub day_of_the_year {
	my ($self, $callback) = @_;
	my $day_of_the_year = [				
		'on the 1st day of the year'       => {
			callback => $callback,
			callback_data => ['byyearday', 'on the 1st day of the year', 1],
		},
		'on the 2nd day of the year'       => {
			callback => $callback,
			callback_data => ['byyearday', 'on the 2nd day of the year', 2],
		},
		'on the last day of the year'       => {
			callback => $callback,
			callback_data => ['byyearday', 'on the last day of the year', -1],
		},
	];
	return $day_of_the_year;
}

sub month_of_the_year {
	my ($self, $callback) = @_;
	my $day_of_the_year = [				
		'during the month of January'       => {
			callback => $callback,
			callback_data => ['bymonth','during the month of January', 1]
		},
		'during the month of February'       => {
			callback => $callback,
			callback_data => ['bymonth','during the month of February', 2]
		},
		'during the month of March'       => {
			callback => $callback,
			callback_data => ['bymonth','during the month of March', 3]
		},
	];
	return $day_of_the_year;
}

sub weeknumber_of_the_year {
	my ($self, $callback) = @_;
	my $weeknumber_of_the_year = [		
		'during the 1st week of the year'       => {
			callback => $callback,
			callback_data => ['byweekno','during the 1st week of the year', 1],
		},
		'during the 2nd week of the year'       => {
			callback => $callback,
			callback_data => ['byweekno','during the 2nd week of the year', 2],
		},
		'during the last week of the year'       => {
			callback => $callback,
			callback_data => ['byweekno','during the last week of the year', -1],
		},
	];	
	return $weeknumber_of_the_year;
}

sub month_day_by_week {
	my ($self, $callback) = @_;
	my $month_day_by_week = [
		'Sunday'       => {
			item_type  => '<Branch>',			
			children => [
				'on the 1st Sunday of the month'       => {
					callback => $callback,
					callback_data => ['byday', 'on the 1st Sunday of the month', '1su'],
				},
				'on the last Sunday of the month'       => {
					callback => $callback,
					callback_data => ['byday', 'on the last Sunday of the month', '-1su'],
				},
			],
		},
	];
	return $month_day_by_week;
}

sub month_day_by_day {
	my ($self, $callback) = @_;
	my $month_day = [
		'on the 1st day of the month'       => {
			callback => $callback,
			callback_data => ['bymonthday', 'on the 1st day of the month', 1],
		},
		'on the 2nd day of the month'       => {
			callback => $callback,
			callback_data => ['bymonthday', 'on the 2nd day of the month', 2],
		},
		'on the 3rd day of the month'       => {
			callback => $callback,
			callback_data => ['bymonthday', 'on the 3rd day of the month', 3],
		},
	];
	return $month_day;
}

sub week_day {
	my ($self, $callback) = @_;
	my $day_of_the_week = [
		'on the Sunday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Sunday', 'su'],
		},
		'on the Monday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Monday', 'mo'],
		},
		'on the Tuesday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Tuesday', 'tu'],
		},
		'on the Wednesday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Wednesday', 'we'],
		},
		'on the Thursday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Thursday', 'th'],
		},
		'on the Friday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Friday', 'fr'],
		},
		'on the Saturday'       => {
			callback => $callback,
			callback_data => ['byday', 'on the Saturday', 'sa'],
		},
	];
	return $day_of_the_week;
}

1;

__END__
=head1 NAME

Gtk2::Ex::ICal::Recur::Selection - This class is not to be used directly. This is just a 
helper class for the C<Gtk2::Ex::ICal::Recur> module.

=head1 AUTHOR

Ofey Aikon, C<< <ofey.aikon at gmail dot com> >>

=head1 BUGS

You tell me. Send me an email !

=head1 ACKNOWLEDGEMENTS

To the wonderful gtk-perl-list.

=head1 COPYRIGHT & LICENSE

Copyright 2004 Ofey Aikon, All Rights Reserved.
This library is free software; you can redistribute it and/or modify it under the terms of the GNU Library General Public License as published by the Free Software Foundation; 
This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License for more details.
You should have received a copy of the GNU Library General Public License along with this library; if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307 USA.

=head1 SEE ALSO

Gtk2::Ex::ICal::Recur

=cut
