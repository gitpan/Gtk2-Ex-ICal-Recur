# COPYRIGHT
# Copyright (C) 2005 ofey.aikon@gmail.com
# This library is free software; you can redistribute it and/or modify it under the terms of the 
# GNU Library General Public License as published by the Free Software Foundation; 
# This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Library General Public License for more details.
# You should have received a copy of the GNU Library General Public License along with this library;
# if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307 USA.

package Gtk2::Ex::ICal::Recur;

our $VERSION = '0.01';

use strict;
use warnings;
use Gtk2 '-init';
use Gtk2::Ex::Simple::Menu;
use Glib qw /TRUE FALSE/;
use Data::Dumper;
use Gtk2::Ex::ICal::Recur::Selection;
use DateTime::Event::ICal;

sub new {
	my ($class, $column_names, $data_attributes) = @_;
	my $self  = {};
	$self->{freqspinbutton} = Gtk2::SpinButton->new_with_range(1,100,1);
	$self->{freqcombobox} = Gtk2::ComboBox->new_text();	
	$self->{recurrencepatterntable} = Gtk2::Table->new(1,1,FALSE);
	$self->{widgets} = undef;
	$self->{buttons} = undef;
	$self->{freqchoices} = [ 
		{ 'label' => 'Year(s)' , 'code' => 'yearly' },
		{ 'label' => 'Month(s)', 'code' => 'monthly' },
		{ 'label' => 'Week(s)' , 'code' => 'weekly' },
		{ 'label' => 'Day(s)'  , 'code' => 'daily' },
	];	

	$self->{icalselection} = Gtk2::Ex::ICal::Recur::Selection->new;
	bless ($self, $class);
	$self->{widget} = $self->package_all;
	return $self;
}

sub update_preview {
	my ($self) = @_;
	my $list = [
		['Apr 1, 2005'],
		['Apr 2, 2005'],
		['Apr 3, 2005'],
		['Apr 4, 2005'],
	];
	my $temp = [
		['Generating Preview'],
		['Please wait...'],
	];
	my $none= [
		['No dates matching'],
		['your criteria...'],
	];
	@{$self->{preview}->{slist}->{data}} = @$temp;
	$self->{preview}->{slist}->show_all;
	Gtk2->main_iteration while Gtk2->events_pending;
	$self->{model} = $self->get_model;
	my $date_list = $self->generate_date_list($self->{model});
	if ($#{@$date_list} >= 0) {
		@{$self->{preview}->{slist}->{data}} = @$date_list;
	} else {
		@{$self->{preview}->{slist}->{data}} = @$none;
	}
	#@{$self->{preview}->{slist}->{data}} = @$list;
}

sub set_model {
	my ($self, $model) = @_;
	$self->{model} = $model;
	$self->{widgets} = undef;
	my $temphash = $self->controller(0, 0);
	$self->{widgets}->[0]->[0] = $self->create_box(0,0,$temphash);
	$self->packbox();
	$self->{freqspinbutton}->set_value($model->{interval});
	my $mapped = { 'yearly' => 0, 'monthly' => 1, 'weekly' => 2, 'daily' => 3 };
	$self->{freqcombobox}->set_active($mapped->{$model->{freq}});
	if ($model->{freq} eq 'yearly') {
		if ($model->{bymonth}) {
			$self->set_month_of_the_year($model, 0);
			if ($model->{bymonthday}) {
				$self->set_month_day_by_day($model, 1);
			} elsif ($model->{byday}) {
				$self->set_month_day_by_week($model, 1);
			}
		} elsif ($model->{byyearday}) {
			$self->set_day_of_the_year($model, 0);
		} elsif ($model->{byweekno}) {
			$self->set_weeknumber_of_the_year($model, 0);
			if ($model->{byday}) {
				$self->set_week_day($model, 1);
			}
		}
	} elsif ($model->{freq} eq 'monthly') {
		if ($model->{bymonthday}) {
			$self->set_month_day_by_day($model, 0);
		} elsif ($model->{byday}) {
			$self->set_month_day_by_week($model, 0);
		}
	} elsif ($model->{freq} eq 'weekly') {
		if ($model->{byday}) {
			$self->set_week_day($model, 0);
		}
	} elsif ($model->{freq} eq 'daily') {
		# Save this for hourly
	}
	if ($model->{dtstart}) {
		$self->{duration}->{dtstart}->select_month($model->{dtstart}->{month}, $model->{dtstart}->{year});
		$self->{duration}->{dtstart}->select_day($model->{dtstart}->{day});
	}	
	if ($model->{dtend}) {
		$self->{duration}->{dtend}->select_month($model->{dtend}->{month}, $model->{dtend}->{year});
		$self->{duration}->{dtend}->select_day($model->{dtend}->{day});
		$self->{duration}->{end_on_radio}->set_active(TRUE);
	} elsif ($model->{count}) {
		$self->{duration}->{count}->set_value($model->{count});
		$self->{duration}->{end_after_radio}->set_active(TRUE);
	}
}

sub get_model {
	my ($self) = @_;
	my $model;
	my $freqcombochoice = $self->{freqchoices}->[$self->{freqcombobox}->get_active()]->{'code'};
	$model->{freq} = $freqcombochoice;
	$model->{interval} = $self->{freqspinbutton}->get_value;
	foreach my $level (@{$self->{buttons}}) {
		my $i = 0;
		foreach my $count (@$level) {
			my $type = $count->{type};
			my $code = $count->{code};
			$model->{$type}->[$i++] = $code;
		}
	}
	$model->{'dtstart'} = $self->{'dtstart'};
	if ($self->{duration}->{end_on_radio}->get_active) {
		$model->{'dtend'} = $self->{'dtend'} if $self->{'dtend'};
	} else {
		$model->{'count'} = $self->{duration}->{'count'}->get_value if $self->{duration}->{'count'};	
	}
	$self->{model} = $model;
	return $model;
}

##############################################
# All methods below this are private methods #
##############################################

sub generate_date_list {
	my ($self, $origmodel) = @_;
	my $model;
	%$model = %$origmodel;
	my @list;
	$model->{dtstart} = hash_to_datetime($model->{dtstart}) if ($model->{dtstart});
	$model->{dtend} = hash_to_datetime($model->{dtend}) if ($model->{dtend});
	$self->{preview}->{progressbar}->pulse;
	my $set = DateTime::Event::ICal->recur(%$model);
	my $iter = $set->iterator;
	my $i = 0;
	while ( my $dt = $iter->next ) {
		push @list, $dt->ymd('/');
		$i++;
		#last if ($i>10);
		#$self->{preview}->{progressbar}->set_fraction($i/10);
		Gtk2->main_iteration while Gtk2->events_pending;
	}
	$self->{preview}->{progressbar}->set_fraction(1);
	return \@list;
}

sub hash_to_datetime {
	my ($hash) = @_;
	my $dt = DateTime->new(%$hash);
	return $dt;
}

sub package_all {
	my ($self) = @_;
	my $exceptions = exceptions();
	my $duration = $self->duration();
	my $preview = $self->preview();

	my $exceptions_frame = Gtk2::Frame->new('Exceptions');
	my $duration_frame = Gtk2::Frame->new('Duration');
	my $recur_frame = Gtk2::Frame->new('Recurrence Pattern');
	my $preview_frame = Gtk2::Frame->new('Preview');

	my $vbox = Gtk2::VBox->new(FALSE);
	$vbox->pack_start($duration, FALSE, FALSE, 0);
	$duration_frame->add($vbox);
	$exceptions_frame->add($exceptions);
	$recur_frame->add($self->get_widget);
	$preview_frame->add($preview);

	my $hbox = Gtk2::HBox->new(FALSE);
	$hbox->pack_start($duration_frame, FALSE, FALSE, 0);
	$hbox->pack_start($exceptions_frame, TRUE, TRUE, 0);

	my $mainvbox = Gtk2::VBox->new(FALSE);
	$mainvbox->pack_start($recur_frame, TRUE, TRUE, 0);
	$mainvbox->pack_start($hbox, FALSE, FALSE, 0);

	my $mainhbox = Gtk2::HBox->new(FALSE);
	$mainhbox->pack_start($mainvbox, TRUE, TRUE, 0);
	$mainhbox->pack_start($preview_frame, FALSE, FALSE, 0);
	
	return $mainhbox;
}

sub preview {
	my ($self) = @_;
	my $vbox = Gtk2::VBox->new(FALSE);
	my $slist = Gtk2::Ex::Simple::List->new ('Exceptions'    => 'text',);
	$slist->set_headers_visible(FALSE);
	$self->{preview}->{slist} = $slist;
	my $scroll = Gtk2::ScrolledWindow->new;
	$scroll->set_policy('never','automatic');
	$scroll->add($slist);
	my $cal = Gtk2::Calendar->new;
	my $previewprogress = Gtk2::ProgressBar->new;
	$self->{preview}->{progressbar} = $previewprogress;
	$vbox->pack_start($scroll, TRUE, TRUE, 0);
	$vbox->pack_start($previewprogress, FALSE, FALSE, 0);
	#$vbox->pack_start($cal, FALSE, FALSE, 0);
	return $vbox;
}

sub duration {
	my ($self) = @_;
	my $table = Gtk2::Table->new(3, 4, FALSE);
	my $start_date = $self->get_date_setter('dtstart', $self->{dtstart});
	
	my $start_date_label = Gtk2::Label->new('Starting on');
	my $end_on_date  = $self->get_date_setter('dtend');
	my $end_on_label = Gtk2::Label->new('and ending on');
	my $end_after_label = Gtk2::Label->new('and ending after');
	my $count = Gtk2::SpinButton->new_with_range(1,100,1);
	$self->{duration}->{count} = $count;
	my $occurrences_label = Gtk2::Label->new('occurrences');
	
	$table->attach_defaults($start_date_label,1,2,0,1);
	$table->attach_defaults($start_date,2,3,0,1);
	my $end_on_radio = Gtk2::RadioButton->new;
	my $end_after_radio = Gtk2::RadioButton->new($end_on_radio);
	$self->{duration}->{end_on_radio} = $end_on_radio;
	$self->{duration}->{end_after_radio} = $end_after_radio;
	
	$end_on_date->set_sensitive($end_on_radio->get_active);
	$end_on_label->set_sensitive($end_on_radio->get_active);
	$end_after_label->set_sensitive($end_after_radio->get_active);
	$count->set_sensitive($end_after_radio->get_active);
	$occurrences_label->set_sensitive($end_after_radio->get_active);

	$end_on_radio->signal_connect('toggled' => 
		sub {
			$end_on_date->set_sensitive($end_on_radio->get_active);
			$end_on_label->set_sensitive($end_on_radio->get_active);
			$end_after_label->set_sensitive($end_after_radio->get_active);
			$count->set_sensitive($end_after_radio->get_active);
			$occurrences_label->set_sensitive($end_after_radio->get_active);
		}
	);
	
	$table->attach_defaults($end_on_radio,0,1,1,2);
	$table->attach_defaults($end_on_label,1,2,1,2);
	$table->attach_defaults($end_on_date,2,3,1,2);

	$table->attach_defaults($end_after_radio,0,1,2,3);
	$table->attach_defaults($end_after_label,1,2,2,3);
	$table->attach_defaults($count,2,3,2,3);
	$table->attach_defaults($occurrences_label,3,4,2,3);
	return $table;
}

sub get_date_setter{
	my ($recur, $key) = @_;
	my $hbox = Gtk2::HBox->new(FALSE);
	my $date_label = Gtk2::Label->new;
	my $cal = Gtk2::Calendar->new;
	$recur->{duration}->{$key} = $cal;
	$cal->signal_connect('day-selected' => 
		sub {
			my ($year, $month, $day) = $cal->get_date;
			$recur->{$key} = { year => $year, month => $month, day => $day };
			$month = month()->[$month];
			my $date_str = "$month $day \, $year";
			$date_label->set_label($date_str);
		}
	);
	my ($year, $month, $day) = $cal->get_date;
	$recur->{$key} = { year => $year, month => $month, day => $day };
	$month = month()->[$month];
	my $date_str = "$month $day \, $year";
	$date_label->set_label($date_str);
	my $date_cal_button = Gtk2::Button->new_from_stock(' ^ ');
	$hbox->pack_start($date_cal_button, FALSE, FALSE, 0);
	$hbox->pack_start($date_label, FALSE, TRUE, 0);
	$date_cal_button->signal_connect('button-release-event' => 
		sub {
			my ($self, $event) = @_;
			my $calwindow = Gtk2::Window->new('popup');
			my $vbox = Gtk2::VBox->new;
			my $ok = Gtk2::Button->new_from_stock('gtk-ok');
			$ok->signal_connect('clicked' => 
				sub {
					$calwindow->hide;
				}
			);
			my $hbox = Gtk2::HBox->new;
			$hbox->pack_start(Gtk2::Label->new, TRUE, TRUE, 0);
			$hbox->pack_start($ok, TRUE, TRUE, 0);
			$hbox->pack_start(Gtk2::Label->new, TRUE, TRUE, 0);
			$vbox->pack_start($cal, TRUE, TRUE, 0);
			$vbox->pack_start($hbox, TRUE, TRUE, 0);
			$calwindow->add($vbox);
			$calwindow->set_position('mouse');
			$calwindow->show_all;		}
	);
	return $hbox;
}

sub exceptions {
	my $slist = Gtk2::Ex::Simple::List->new ('Exceptions'    => 'text',);
	$slist->set_headers_visible(FALSE);
	my $buttonbox = Gtk2::HBox->new;
	my $addbutton = Gtk2::Button->new_from_stock('gtk-add');
	my $removebutton = Gtk2::Button->new_from_stock('gtk-remove');
	$addbutton->signal_connect('button-release-event' => 
		sub {
			my ($self, $event) = @_;
			my $cal = Gtk2::Calendar->new;
			my $calwindow = Gtk2::Window->new('popup');
			my $vbox = Gtk2::VBox->new;
			my $ok = Gtk2::Button->new_from_stock('gtk-ok');
			my $cancel= Gtk2::Button->new_from_stock('gtk-cancel');
			$ok->signal_connect('clicked' => 
				sub {
					my ($year, $month, $day) = $cal->get_date;
					$month = month()->[$month];
					push @{$slist->{data}}, ["(not yet implemented)"] if ($#{@{$slist->{data}}} <= 0);
					push @{$slist->{data}}, ["$month $day\, $year"];
					$calwindow->hide;
				}
			);
			$cancel->signal_connect('clicked' => 
				sub {
					$calwindow->hide;
				}
			);
			my $hbox = Gtk2::HBox->new;
			$hbox->pack_start($ok, TRUE, TRUE, 0);
			$hbox->pack_start($cancel, TRUE, TRUE, 0);
			$vbox->pack_start($cal, TRUE, TRUE, 0);
			$vbox->pack_start($hbox, TRUE, TRUE, 0);
			$calwindow->add($vbox);
			$calwindow->set_position('mouse');
			$calwindow->show_all;
		}
	);
	$buttonbox->pack_start($addbutton, TRUE, TRUE, 0);
	$buttonbox->pack_start($removebutton, TRUE, TRUE, 0);
	my $vbox = Gtk2::VBox->new;
	my $scroll = Gtk2::ScrolledWindow->new;
	$scroll->set_policy('never','automatic');
	$scroll->add($slist);
	$vbox->pack_start($scroll, TRUE, TRUE, 0);
	$vbox->pack_start($buttonbox, FALSE, FALSE, 0);
	return $vbox;
}

sub month {
	return [
		'January',
		'February',
		'March',
		'April',
		'June',
		'July',
		'August',
		'September',
		'October',
		'Novemeber',
		'December',
	];
}


sub get_widget {
	my ($self) = @_;
	foreach my $choice (@{$self->{freqchoices}}) {
		$self->{freqcombobox}->append_text($choice->{'label'});	
	}
	my $freqhbox = Gtk2::HBox->new(FALSE);
	$freqhbox->pack_start(Gtk2::Label->new('Occurs every'), FALSE, FALSE, 0);
	$freqhbox->pack_start($self->{freqspinbutton}, FALSE, FALSE, 0);
	$freqhbox->pack_start($self->{freqcombobox}, FALSE, FALSE, 0);
	
	$self->{freqcombobox}->signal_connect('changed' => 
		sub {
			$self->{widgets} = undef;
			$self->{buttons} = undef;
			my $temphash = $self->controller(0, 0);
			$self->{widgets}->[0]->[0] = $self->create_box(0,0,$temphash);
			$self->packbox();
		}
	);
	my $scroll = Gtk2::ScrolledWindow->new;
	$scroll->add_with_viewport($self->{recurrencepatterntable});
	$scroll->set_policy('never', 'automatic');
	$self->{recurrencepatterntable}->set_col_spacings(1);
	$self->{recurrencepatterntable}->set_row_spacings(1);
	
	my $vbox = Gtk2::VBox->new(FALSE, 5);
	$vbox->pack_start($freqhbox, FALSE, FALSE, 0);
	$vbox->pack_start($scroll, TRUE, TRUE, 0);
	return $vbox;
}


sub set_month_of_the_year {
	my ($self, $model, $level) = @_;
	my @months = @{$model->{bymonth}};
	my $list = $self->{icalselection}->month_of_the_year();
	my $hash;
	for (my $i=0; $i<=$#{@$list}; $i+=2) {
		my $x = $list->[$i+1]->{callback_data};
		$hash->{$x->[2]} = $x->[1];
	}
	$self->update_ui_from_model(\@months, $hash, '/^/by month of the year/', $level);
}

sub set_day_of_the_year {
	my ($self, $model, $level) = @_;
	my @yeardays = @{$model->{byyearday}};
	my $list = $self->{icalselection}->day_of_the_year();
	my $hash;
	for (my $i=0; $i<=$#{@$list}; $i+=2) {
		my $x = $list->[$i+1]->{callback_data};
		$hash->{$x->[2]} = $x->[1];
	}
	$self->update_ui_from_model(\@yeardays, $hash, '/^/by day of the year/', $level);
}

sub set_weeknumber_of_the_year {
	my ($self, $model, $level) = @_;
	my @weeknums = @{$model->{byweekno}};
	my $list = $self->{icalselection}->weeknumber_of_the_year();
	my $hash;
	for (my $i=0; $i<=$#{@$list}; $i+=2) {
		my $x = $list->[$i+1]->{callback_data};
		$hash->{$x->[2]} = $x->[1];
	}
	$self->update_ui_from_model(\@weeknums, $hash, '/^/by weeknumber of the year/', $level);
}

sub set_week_day {
	my ($self, $model, $level) = @_;
	my @weekdays = @{$model->{byday}};
	my $list = $self->{icalselection}->week_day();
	my $hash;
	for (my $i=0; $i<=$#{@$list}; $i+=2) {
		my $x = $list->[$i+1]->{callback_data};
		$hash->{$x->[2]} = $x->[1];
	}
	$self->update_ui_from_model(\@weekdays, $hash, '/^/', $level);
}

sub set_month_day_by_day {
	my ($self, $model, $level) = @_;
	my @monthdays = @{$model->{bymonthday}};
	my $list = $self->{icalselection}->month_day_by_day();
	my $hash;
	for (my $i=0; $i<=$#{@$list}; $i+=2) {
		my $x = $list->[$i+1]->{callback_data};
		$hash->{$x->[2]} = $x->[1];
	}
	$self->update_ui_from_model(\@monthdays, $hash, '/^/by day/', $level);
}

sub set_month_day_by_week {
	my ($self, $model, $level) = @_;
	my @monthdays = @{$model->{byday}};
	my $list = $self->{icalselection}->month_day_by_week();
	my $hash;
	for (my $i=0; $i<=$#{@$list}; $i+=2) {
		my $x = $list->[$i+1]->{children};				
		for (my $j=0; $j<=$#{@$x}; $j+=2) {
			my $y = $x->[$j+1]->{callback_data};
			$hash->{$y->[2]} = $list->[$i].'/'.$y->[1];
		}
	}
	$self->update_ui_from_model(\@monthdays, $hash, '/^/by week day/', $level);
}

sub update_ui_from_model {
	my ($self, $list, $hash, $string, $level) = @_;
	for (my $i=0; $i<=$#{@$list}; $i++) {
		$self->{buttons}->[$level]->[$i]->{simplemenu}->get_widget($string.$hash->{$list->[$i]})->activate;
		$self->{buttons}->[$level]->[$i]->{next}->set_sensitive(FALSE);
		if ($i<$#{@$list}) {
			$self->addbuttonclicked($level, $i);
			$self->{buttons}->[$level]->[$i]->{add}->set_sensitive(FALSE);
			$self->{buttons}->[$level]->[$i]->{remove}->set_sensitive(FALSE);
		} else {
			$self->nextbuttonclicked($level, $i);
		}
	}
}


sub controller {
	my ($self, $level, $count) = @_;
	my $temphash = undef;
	if ($level == 0) {
		my $freqcombochoice = $self->{freqchoices}->[$self->{freqcombobox}->get_active()]->{'code'};
		if ($freqcombochoice eq 'yearly') {		
			$temphash = $self->month_or_day_of_the_year($level,$count);
		} elsif ($freqcombochoice eq 'monthly') {
			$temphash = $self->day_of_the_month($level,$count);
		} elsif ($freqcombochoice eq 'weekly') {
			$temphash = $self->day_of_the_week($level,$count);
		} elsif ($freqcombochoice eq 'daily') {
		}
	} elsif ($level == 1) {
		my $parent = $self->{buttons}->[$level-1]->[0]->{type};
		if ($parent eq 'bymonth') {
			$temphash = $self->day_of_the_month($level,$count);
		} elsif ($parent eq 'byyearday') {
		
		} elsif ($parent eq 'byweekno') {			
			$temphash = $self->day_of_the_week($level,$count);
		}
	}
	if (!$temphash) {
		# print "controller called with $level $count Un-implemented\n";
	}
	return $temphash;
}

sub packbox {
	my ($self) = @_;
	my $rows = 0;
	foreach my $level (@{$self->{widgets}}) {
		foreach my $count (@$level) {
			$rows++ if ($count);
		}
	}
	# First I will clear the contents of the $table
	my @children = $self->{recurrencepatterntable}->get_children;
	foreach my $child (@children) {
		$self->{recurrencepatterntable}->remove($child);
	}

	# Now I will resize the table	
	$self->{recurrencepatterntable}->resize($rows,5) if ($rows > 0);
	
	my $row = 0;
	foreach my $level (@{$self->{widgets}}) {
		foreach my $count (@$level) {
			my $col = 0;
			foreach my $widget (@$count) {
				if ($widget) {
					$self->{recurrencepatterntable}->attach($widget, $col, $col+1, $row, $row+1, 'fill', 'fill', 0, 0) ;
					$col++;
				}
			}
			$row++;
		}
	}
	$self->{recurrencepatterntable}->show_all;
}

sub create_box {
	my ($self, $level, $count, $temphash) = @_;
	return undef unless $temphash;

	my $box_as_array = [];
	my $hbox = Gtk2::HBox->new(FALSE);
	my $addbutton = Gtk2::Button->new_with_label('add another');
	my $nextbutton = Gtk2::Button->new_with_label('Continue>>');
	my $removebutton = Gtk2::Button->new_with_label('remove this');
	$self->{buttons}->[$level]->[$count]->{add} = $addbutton;
	$self->{buttons}->[$level]->[$count]->{next} = $nextbutton;
	$self->{buttons}->[$level]->[$count]->{remove} = $removebutton;	
	$addbutton->set_sensitive(FALSE);
	$nextbutton->set_sensitive(FALSE);
	$removebutton->set_sensitive(FALSE);
	
	$addbutton->signal_connect('clicked' => 
		sub {
			$addbutton->set_sensitive(FALSE);
			$nextbutton->set_sensitive(FALSE);
			$removebutton->set_sensitive(FALSE);
			$self->addbuttonclicked($level, $count);
		}
	);
	$nextbutton->signal_connect('clicked' => 
		sub {
			$nextbutton->set_sensitive(FALSE);
			$self->nextbuttonclicked($level, $count);
		}
	);
	$removebutton->signal_connect('clicked' => 
		sub {
			$self->removebuttonclicked($level, $count);
		}
	);
	
	$self->{buttons}->[$level]->[$count]->{simplemenu} = $temphash->{simplemenu};	
	$self->{buttons}->[$level]->[$count]->{label} = $temphash->{label};	
	push @$box_as_array, $temphash->{simplemenu}->{widget};
	push @$box_as_array, $temphash->{label};
	push @$box_as_array, $addbutton;
	push @$box_as_array, $removebutton;
	push @$box_as_array, $nextbutton;
	
	return $box_as_array;
}

sub nextbuttonclicked {
	my ($self, $level, $count) = @_;
	# If there are rows underneath
	return if ($#{@{$self->{widgets}->[$level+1]}} >= 0);	
	my $currentcount = $#{$self->{widgets}->[$level+1]};
	my $temphash = $self->controller($level+1, $currentcount+1);
	$self->{widgets}->[$level+1]->[$currentcount+1] = $self->create_box($level+1, $currentcount+1, $temphash);
	$self->packbox();
}

sub addbuttonclicked {
	my ($self, $level, $count) = @_;
	my $temphash = $self->controller($level, $count+1);
	$self->{buttons}->[$level]->[$count]->{simplemenu}->{widget}->set_sensitive(FALSE);
	if ($level > 0) {
		my $count = $#{$self->{widgets}->[$level-1]};
		$self->{buttons}->[$level-1]->[$count]->{next}->set_sensitive(FALSE);
	}
	$self->{widgets}->[$level]->[$count+1] = $self->create_box($level, $count+1, $temphash);
	if ($#{@{$self->{widgets}->[$level+1]}} >= 0) {
		$self->{buttons}->[$level]->[$count+1]->{next}->set_sensitive(FALSE);		
	}
	$self->packbox();
}

sub removebuttonclicked {
	my ($self, $level, $count) = @_;
	delete($self->{widgets}->[$level]->[$count]);
	delete($self->{buttons}->[$level]->[$count]);
	if ($count>0) {
		$self->{buttons}->[$level]->[$count-1]->{simplemenu}->{widget}->set_sensitive(TRUE);
		$self->{buttons}->[$level]->[$count-1]->{add}->set_sensitive(TRUE);
		if (!$self->{widgets}->[$level+1]) {
			$self->{buttons}->[$level]->[$count-1]->{next}->set_sensitive(TRUE);
		}
		$self->{buttons}->[$level]->[$count-1]->{remove}->set_sensitive(TRUE);
	} else {
		for (my $i=$level+1; $i<=$#{@{$self->{widgets}}}; $i++) {
			delete($self->{widgets}->[$i]);
		}
		my $lastcount = $#{@{$self->{widgets}->[$level-1]}};
		$self->{buttons}->[$level-1]->[$lastcount]->{next}->set_sensitive(TRUE);
	}
	$self->packbox();
}

sub day_of_the_month {
	my ($self, $level, $count) = @_;
	my $label = Gtk2::Label->new('choose a day/weekday');
	my $callback = sub {
		my ($data) = @_;
		my $type = $data->[0];
		my $text = $data->[1];
		my $code = $data->[2];
		$self->{buttons}->[$level]->[$count]->{code} = $code;
		$self->{buttons}->[$level]->[$count]->{type} = $type;
		$text = "and $text" if ($count > 0);
		$label->set_label($text);
		$self->{buttons}->[$level]->[$count]->{add}->set_label('add another day');
		$self->{buttons}->[$level]->[$count]->{remove}->set_label('remove this day');
		$self->{buttons}->[$level]->[$count]->{add}->set_sensitive(TRUE);
		#$self->{buttons}->[$level]->[$count]->{next}->set_sensitive(TRUE);
		$self->{buttons}->[$level]->[$count]->{remove}->set_sensitive(TRUE);
	};
	my $menu_tree = [
		'^'  => {
			item_type  => '<Branch>',
			children => [
				'by day' => {
					item_type  => '<Branch>',
					children => $self->{icalselection}->month_day_by_day($callback),
				},
				'by week day' => {
					item_type  => '<Branch>',
					children => $self->{icalselection}->month_day_by_week($callback),
				},
			],
		},
	];
	if ($count > 0) {
		# Understand the $count=0 selection
		my $brother = $self->{buttons}->[$level]->[0]->{type};
		if ($brother eq 'byday') {
			$menu_tree = [
				'^'  => {
					item_type  => '<Branch>',
					children => [
						'by week day' => {
							item_type  => '<Branch>',
							children => $self->{icalselection}->month_day_by_week($callback),
						},
					],
				},
			];
		} elsif ($brother eq 'bymonthday'){
			$menu_tree = [
				'^'  => {
					item_type  => '<Branch>',
					children => [
						'by day' => {
							item_type  => '<Branch>',
							children => $self->{icalselection}->month_day_by_day($callback),
						},
					],
				},
			];
		}
	}
	my $menu = Gtk2::Ex::Simple::Menu->new(menu_tree => $menu_tree);
	my $temphash = {};
	$temphash->{simplemenu} = $menu;
	$temphash->{label} = $label;
	return $temphash;
}

sub day_of_the_week {
	my ($self, $level, $count) = @_;
	my $label = Gtk2::Label->new('choose a day of the week');
	my $callback = sub {
		my ($data) = @_;
		my $type = $data->[0];
		my $text = $data->[1];
		my $code = $data->[2];
		$self->{buttons}->[$level]->[$count]->{code} = $code;
		$self->{buttons}->[$level]->[$count]->{type} = $type;
		$text = "and $text" if ($count > 0);
		$label->set_label($text);
		$self->{buttons}->[$level]->[$count]->{add}->set_label('add another weekday');
		$self->{buttons}->[$level]->[$count]->{remove}->set_label('remove this weekday');
		$self->{buttons}->[$level]->[$count]->{add}->set_sensitive(TRUE);
		#$self->{buttons}->[$level]->[$count]->{next}->set_sensitive(TRUE);
		$self->{buttons}->[$level]->[$count]->{remove}->set_sensitive(TRUE);
	};
	my $menu_tree = [
		'^'  => {
			item_type  => '<Branch>',
			children => $self->{icalselection}->week_day($callback),
		},
	];

	my $menu = Gtk2::Ex::Simple::Menu->new(menu_tree => $menu_tree);
	my $temphash = {};
	$temphash->{simplemenu} = $menu;
	$temphash->{label} = $label;
	return $temphash;
}

sub month_or_day_of_the_year {
	my ($self, $level, $count) = @_;
	my $label = Gtk2::Label->new('choose a month/week/day');
	my $callback = sub {
		my ($data) = @_;
		my $type = $data->[0];
		my $text = $data->[1];
		my $code = $data->[2];
		$self->{buttons}->[$level]->[$count]->{code} = $code;
		$self->{buttons}->[$level]->[$count]->{type} = $type;
		$text = "and $text" if ($count > 0);
		$label->set_label($text);
		if ($type eq 'bymonth') {
			$self->{buttons}->[$level]->[$count]->{add}->set_label('add another month');
			$self->{buttons}->[$level]->[$count]->{remove}->set_label('remove this month');
			if ($#{@{$self->{widgets}->[$level+1]}} <= 0) {
				$self->{buttons}->[$level]->[$count]->{next}->set_sensitive(TRUE);
			}
		} elsif ($type eq 'byyearday') {
			$self->{buttons}->[$level]->[$count]->{add}->set_label('add another day');
			$self->{buttons}->[$level]->[$count]->{remove}->set_label('remove this day');
		} elsif ($type eq 'byweekno') {
			$self->{buttons}->[$level]->[$count]->{add}->set_label('add another week');
			$self->{buttons}->[$level]->[$count]->{remove}->set_label('remove this week');
			if ($#{@{$self->{widgets}->[$level+1]}} <= 0) {
				$self->{buttons}->[$level]->[$count]->{next}->set_sensitive(TRUE);
			}
		}
		$self->{buttons}->[$level]->[$count]->{add}->set_sensitive(TRUE);
		$self->{buttons}->[$level]->[$count]->{remove}->set_sensitive(TRUE);
	};
	my $menu_tree = [
		'^'  => {
			item_type  => '<Branch>',
			children => [
				'by month of the year' => {
					item_type  => '<Branch>',
					children => $self->{icalselection}->month_of_the_year($callback),
				},
				'by day of the year' => {
					item_type  => '<Branch>',
					children => $self->{icalselection}->day_of_the_year($callback),
				},
				'by weeknumber of the year' => {
					item_type  => '<Branch>',
					children => $self->{icalselection}->weeknumber_of_the_year($callback),
				},
			],
		},
	];
	if ($count > 0) {
		# Understand the $count=0 selection
		my $brother = $self->{buttons}->[$level]->[0]->{type};
		if ($brother eq 'bymonth') {
			$label->set_label('choose another month');
			$menu_tree = [
				'^'  => {
					item_type  => '<Branch>',
					children => [
						'by month of the year' => {
							item_type  => '<Branch>',
							children => $self->{icalselection}->month_of_the_year($callback),
						},
					],
				},
			];
		} elsif ($brother eq 'byweekno'){
			$label->set_label('choose another weeknumber');
			$menu_tree = [
				'^'  => {
					item_type  => '<Branch>',
					children => [
						'by weeknumber of the year' => {
							item_type  => '<Branch>',
							children => $self->{icalselection}->weeknumber_of_the_year($callback),
						},
					],
				},
			];
		} elsif ($brother eq 'byyearday'){
			$label->set_label('choose another day');
			$menu_tree = [
				'^'  => {
					item_type  => '<Branch>',
					children => [
						'by day of the year' => {
							item_type  => '<Branch>',
							children => $self->{icalselection}->day_of_the_year($callback),
						},
					],
				},
			];
		}				
	}

	my $menu = Gtk2::Ex::Simple::Menu->new(menu_tree => $menu_tree);
	my $temphash = {};
	$temphash->{simplemenu} = $menu;
	$temphash->{label} = $label;
	return $temphash;
}

1;

__END__
