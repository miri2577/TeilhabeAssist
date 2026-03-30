/// Häufige Vornamen in Berlin – multikulturell.
/// Quellen: Standesämter Berlin, beliebte-vornamen.de, internationale Listen.
/// Strategie: Über-Erkennung – im Zweifel lieber zu viel erkennen.
const kFirstNames = <String>{
  // Deutsche Vornamen (häufigste)
  'Alexander', 'Andreas', 'Anna', 'Annett', 'Barbara', 'Benjamin', 'Bernd',
  'Birgit', 'Brigitte', 'Carsten', 'Charlotte', 'Christian', 'Christina',
  'Christine', 'Christoph', 'Claudia', 'Daniel', 'Daniela', 'David',
  'Dennis', 'Detlef', 'Diana', 'Dieter', 'Dirk', 'Doris', 'Dorothea',
  'Eberhard', 'Elke', 'Emma', 'Erik', 'Eva', 'Felix', 'Florian', 'Frank',
  'Franz', 'Friedrich', 'Gabriele', 'Georg', 'Gerhard', 'Gisela', 'Gudrun',
  'Günter', 'Günther', 'Hanna', 'Hannah', 'Hans', 'Harald', 'Heike',
  'Heinz', 'Helga', 'Helmut', 'Henrik', 'Herbert', 'Holger', 'Ilona',
  'Ines', 'Ingrid', 'Ingo', 'Irene', 'Jan', 'Jana', 'Jens', 'Jessica',
  'Joachim', 'Johannes', 'Jonas', 'Julia', 'Julian', 'Jürgen', 'Kai',
  'Karen', 'Karin', 'Karl', 'Karsten', 'Katharina', 'Kathrin', 'Katja',
  'Klaus', 'Konrad', 'Kurt', 'Lars', 'Laura', 'Lena', 'Leon', 'Leonie',
  'Lisa', 'Luise', 'Lukas', 'Manfred', 'Manuel', 'Marco', 'Marcus',
  'Margarete', 'Maria', 'Marie', 'Marina', 'Mario', 'Markus', 'Martin',
  'Martina', 'Matthias', 'Max', 'Maximilian', 'Melanie', 'Michael',
  'Michaela', 'Monika', 'Nadine', 'Nicole', 'Niklas', 'Nina', 'Norbert',
  'Oliver', 'Olaf', 'Patrick', 'Paul', 'Peter', 'Petra', 'Philipp',
  'Rainer', 'Ralf', 'Regina', 'Reinhard', 'Renate', 'Rene', 'Richard',
  'Robert', 'Roland', 'Rolf', 'Rüdiger', 'Sabine', 'Sandra', 'Sarah',
  'Sascha', 'Sebastian', 'Silke', 'Silvia', 'Simon', 'Simone', 'Sophia',
  'Stefan', 'Stefanie', 'Steffen', 'Stephan', 'Susanne', 'Sven', 'Tanja',
  'Thomas', 'Thorsten', 'Tim', 'Tobias', 'Torsten', 'Ulrich', 'Ulrike',
  'Ursula', 'Uwe', 'Vanessa', 'Volker', 'Walter', 'Werner', 'Wiebke',
  'Wilhelm', 'Wolfgang', 'Yvonne',

  // Türkische Vornamen (häufig in Berlin)
  'Ahmet', 'Ali', 'Ayhan', 'Aysel', 'Ayse', 'Ayşe', 'Baris', 'Burak',
  'Cemal', 'Canan', 'Deniz', 'Derya', 'Dilek', 'Elif', 'Emine', 'Emre',
  'Ercan', 'Erdogan', 'Esra', 'Fatih', 'Fatma', 'Fikret', 'Gül', 'Gülten',
  'Hakan', 'Halil', 'Hamza', 'Hasan', 'Hatice', 'Hüseyin', 'Ibrahim',
  'Ismail', 'Kadir', 'Kemal', 'Kenan', 'Leyla', 'Mehmet', 'Melek',
  'Meral', 'Murat', 'Mustafa', 'Nalan', 'Necla', 'Nihat', 'Nuray',
  'Nurhan', 'Okan', 'Omer', 'Ömer', 'Orhan', 'Osman', 'Özlem', 'Recep',
  'Sabri', 'Seher', 'Selim', 'Selma', 'Semra', 'Serdar', 'Serpil',
  'Sevgi', 'Seyhan', 'Sibel', 'Süleyman', 'Taner', 'Turan', 'Tülay',
  'Yasemin', 'Yilmaz', 'Yusuf', 'Zehra', 'Zeynep', 'Zübeyde',

  // Arabische Vornamen (häufig in Berlin)
  'Abdel', 'Abdullah', 'Abdulrahman', 'Ahmad', 'Ahmed', 'Aisha', 'Amina',
  'Amir', 'Bilal', 'Djamila', 'Farid', 'Farida', 'Fatima', 'Hana',
  'Hassan', 'Hussein', 'Jamal', 'Kamal', 'Kareem', 'Khalid', 'Laila',
  'Lina', 'Maher', 'Mahmoud', 'Malak', 'Mariam', 'Mohammed', 'Mohamed',
  'Muhammad', 'Nabil', 'Nadia', 'Naima', 'Nour', 'Omar', 'Rami', 'Rashid',
  'Saber', 'Sahra', 'Said', 'Salim', 'Sami', 'Samira', 'Sara', 'Soraya',
  'Tarek', 'Walid', 'Yara', 'Yasmin', 'Youssef', 'Zainab',

  // Polnische Vornamen (häufig in Berlin)
  'Agnieszka', 'Andrzej', 'Beata', 'Bogdan',
  'Dariusz', 'Dorota', 'Ewa', 'Grzegorz', 'Halina', 'Irena', 'Iwona',
  'Jadwiga', 'Jakub', 'Janusz', 'Joanna', 'Jolanta', 'Katarzyna',
  'Krystyna', 'Krzysztof', 'Małgorzata', 'Marek',
  'Mariusz', 'Mateusz', 'Miroslaw', 'Paweł', 'Piotr', 'Rafal',
  'Renata', 'Stanislaw', 'Tadeusz', 'Tomasz', 'Wieslaw',
  'Wojciech', 'Zbigniew', 'Zofia',

  // Vietnamesische Vornamen (häufig in Berlin)
  'Anh', 'Binh', 'Chi', 'Dung', 'Duc', 'Hai', 'Hanh', 'Hien', 'Hoa',
  'Hong', 'Hung', 'Huong', 'Khanh', 'Lan', 'Linh', 'Long', 'Mai',
  'Minh', 'Nam', 'Nga', 'Ngoc', 'Nhan', 'Nhi', 'Phu', 'Phuong',
  'Quan', 'Quang', 'Quynh', 'Son', 'Tam', 'Thanh', 'Thao', 'Thi',
  'Thien', 'Thu', 'Tien', 'Trang', 'Trung', 'Tuan', 'Tuyen', 'Van',
  'Vinh', 'Vu', 'Xuan', 'Yen',

  // Russische Vornamen (häufig in Berlin)
  'Alexei', 'Anastasia', 'Andrei', 'Boris', 'Dimitri', 'Dmitri', 'Elena',
  'Galina', 'Igor', 'Irina', 'Ivan', 'Jewgeni', 'Konstantin',
  'Larissa', 'Ludmila', 'Maxim', 'Natalja', 'Natalia', 'Natasha',
  'Nikolai', 'Oleg', 'Olga', 'Pavel', 'Sergei', 'Sergej', 'Svetlana',
  'Tatjana', 'Valentina', 'Viktor', 'Vitali', 'Vladimir', 'Wladimir',
  'Yuri',
};
